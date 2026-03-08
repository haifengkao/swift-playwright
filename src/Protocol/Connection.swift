import Foundation

/// Central message router for the Playwright JSON-RPC protocol.
///
/// The connection manages the request/response lifecycle, dispatches
/// server-initiated messages (`__create__`, `__dispose__`), and
/// maintains the GUID-based object registry.
///
/// Use ``start()`` to begin processing messages, then ``sendMessage(guid:method:params:)``
/// to send requests. Call ``close()`` to shut down.
///
/// See: https://github.com/microsoft/playwright-python/blob/main/playwright/_impl/_connection.py
actor Connection: Sendable {
	private var lastId = 0
	private var isClosed = false
	private nonisolated let transport: Transport
	private var messageLoopTask: Task<Void, Never>?
	private var objects: [String: ChannelOwner] = [:]
	private var callbacks: [Int: CheckedContinuation<[String: Any], any Error>] = [:]

	init(transport: Transport) {
		self.transport = transport
	}

	deinit { transport.close() }

	/// Starts the background message processing loop.
	///
	/// Must be called before ``sendMessage(guid:method:params:)``.
	/// The loop runs until the transport closes or ``close()`` is called.
	func start() {
		objects[""] = ChannelOwner(connection: self, parent: nil, type: "", guid: "", initializer: [:])
		messageLoopTask = Task { [weak self, transport] in
			for await payload in transport.messages {
				await self?.receive(payload)
			}

			// transport closed: fail pending callbacks
			await self?.failPendingCallbacks()
		}
	}

	/// Deserializes and dispatches a single raw message from the transport.
	private func receive(_ payload: Data) {
		guard let message = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { return }
		dispatch(message)
	}

	/// Sends a JSON-RPC request and waits for the correlated response.
	///
	/// - Parameter guid: The target object's GUID (empty string for root).
	/// - Parameter method: The RPC method name.
	/// - Parameter params: The parameters to send.
	/// - Returns: The `result` dictionary from the server's response.
	func sendMessage(guid: String, method: String, params: sending [String: Any] = [:]) async throws -> sending [String: Any] {
		guard !isClosed else { throw PlaywrightError.connectionClosed }
		lastId += 1
		let id = lastId

		let message: [String: Any] = [
			"id": id,
			"guid": guid,
			"method": method,
			"params": params,
			"metadata": [
				"apiName": "",
				"internal": true,
				"wallTime": Int(Date().timeIntervalSince1970 * 1000),
			] as [String: Any],
		]

		let data = try JSONSerialization.data(withJSONObject: message)

		return try await withCheckedThrowingContinuation { continuation in
			callbacks[id] = continuation
			transport.send(data)
		}
	}

	/// Looks up a protocol object by GUID.
	func getObject(_ guid: String) -> ChannelOwner? {
		objects[guid]
	}

	/// Shuts down the connection and underlying transport.
	func close() {
		guard !isClosed else { return }
		isClosed = true

		let task = messageLoopTask
		messageLoopTask = nil
		objects.removeAll()
		failPendingCallbacks()
		task?.cancel()
		transport.close()
	}

	/// Drains all pending callbacks and resumes them with ``PlaywrightError/connectionClosed``.
	/// Safe to call multiple times — subsequent calls are no-ops.
	private func failPendingCallbacks() {
		let pending = callbacks
		callbacks.removeAll()
		for (_, callback) in pending {
			callback.resume(throwing: PlaywrightError.connectionClosed)
		}
	}

	// MARK: - Message Dispatch

	private func dispatch(_ message: [String: Any]) {
		// Response to a previous request
		if let id = message["id"] as? Int {
			let callback = callbacks.removeValue(forKey: id)
			guard let callback else { return }

			if let error = message["error"] as? [String: Any] {
				let errorInfo = (error["error"] as? [String: Any]) ?? error
				let msg = errorInfo["message"] as? String ?? "Unknown error"
				callback.resume(throwing: PlaywrightError.serverError(msg))
			} else {
				nonisolated(unsafe) let result = message["result"] as? [String: Any] ?? [:]
				callback.resume(returning: result)
			}
			return
		}

		// Server-initiated message
		let guid = message["guid"] as? String ?? ""
		let method = message["method"] as? String ?? ""
		let params = message["params"] as? [String: Any] ?? [:]

		switch method {
			case "__create__":
				guard let childGuid = params["guid"] as? String, !childGuid.isEmpty else { return }
				let childType = params["type"] as? String ?? ""
				let childInit = params["initializer"] as? [String: Any] ?? [:]

				guard let parent = objects[guid] else { return }

				let child = ObjectFactory.create(
					parent: parent, type: childType, guid: childGuid,
					initializer: childInit
				)
				objects[childGuid] = child
				parent.addChild(child)

			case "__dispose__":
				guard let obj = objects[guid] else { return }
				disposeObject(obj, reason: params["reason"] as? String)

			default:
				// Event dispatch — will be handled in a future version
				break
		}
	}

	/// Recursively disposes an object and its children.
	private func disposeObject(_ obj: ChannelOwner, reason: String? = nil) {
		for child in Array(obj.children.values) {
			disposeObject(child, reason: reason)
		}
		objects.removeValue(forKey: obj.guid)
		obj.parent?.removeChild(obj)
	}
}
