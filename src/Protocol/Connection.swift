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

			// transport closed (crash, kill, pipe break): tear down fully.
			await self?.close()
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
		let (id, data) = try buildMessage(guid: guid, method: method, params: params)

		return try await withCheckedThrowingContinuation { continuation in
			callbacks[id] = continuation
			transport.send(data)
		}
	}

	/// Sends a JSON-RPC message without waiting for a response (fire-and-forget).
	///
	/// Used for `updateSubscription` messages that don't need a response.
	func sendNoReply(guid: String, method: String, params: [String: Any] = [:]) {
		guard !isClosed else { return }
		if let (_, data) = try? buildMessage(guid: guid, method: method, params: params) {
			transport.send(data)
		}
	}

	/// Builds and serializes a JSON-RPC message, returning the assigned ID and serialized data.
	private func buildMessage(guid: String, method: String, params: [String: Any]) throws -> (Int, Data) {
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

		return try (id, JSONSerialization.data(withJSONObject: message))
	}

	/// Looks up a protocol object by GUID.
	func getObject(_ guid: String) -> ChannelOwner? {
		objects[guid]
	}

	/// Resolves a typed object from a dictionary containing a GUID reference.
	///
	/// Expects `dict[key]` to be `{"guid": "some-guid@123"}` and looks up the
	/// corresponding object in the registry.
	///
	/// - Parameter dict: The dictionary containing the GUID reference.
	/// - Parameter key: The key whose value holds the `{"guid": ...}` reference.
	/// - Returns: The resolved object, or `nil` if resolution fails.
	func resolveObject<T: ChannelOwner>(from dict: [String: Any], key: String) -> T? {
		guard let ref = dict[key] as? [String: Any], let guid = ref["guid"] as? String, let obj = objects[guid] as? T
		else { return nil }

		return obj
	}

	/// Resolves an array of GUID references from a dictionary.
	///
	/// Expects `dict[key]` to be `[{"guid": "some@1"}, {"guid": "some@2"}, ...]`.
	func resolveArray<T: ChannelOwner>(from dict: [String: Any], key: String) -> [T] {
		guard let refs = dict[key] as? [[String: Any]] else { return [] }

		return refs.compactMap { ref in
			guard let guid = ref["guid"] as? String else { return nil }
			return objects[guid] as? T
		}
	}

	/// Shuts down the connection and underlying transport.
	func close() {
		guard !isClosed else { return }
		isClosed = true

		let task = messageLoopTask
		messageLoopTask = nil

		// Notify all live objects so they can update state (e.g. Browser.isConnected),
		// then sever the tree so the closed graph doesn't stay reachable.
		for obj in objects.values {
			obj.emit("close", params: [:])
			obj.dispose()
		}

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
				let name = errorInfo["name"] as? String
				var msg = errorInfo["message"] as? String ?? "Unknown error"
				if let log = message["log"] as? [String], !log.isEmpty {
					msg += "\nCall log:\n" + log.joined(separator: "\n") + "\n"
				}
				callback.resume(throwing: PlaywrightError.fromServer(msg, name: name))
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
				child.didCreate { objects[$0] }

			case "__dispose__":
				guard let obj = objects[guid] else { return }
				disposeObject(obj, reason: params["reason"] as? String)

			case "__adopt__":
				guard let childGuid = params["guid"] as? String,
				      let newParent = objects[guid],
				      let child = objects[childGuid]
				else { return }
				child.parent?.removeChild(child)
				newParent.addChild(child)
				child.setParent(newParent)

			default:
				guard let obj = objects[guid] else { return }
				obj.emit(method, params: resolveGuidReferences(in: params))
		}
	}

	/// Resolves GUID references in event params to actual objects.
	///
	/// The server sends `{"page": {"guid": "page@1"}}` — this replaces
	/// those references with the actual `ChannelOwner` instances.
	private func resolveGuidReferences(in params: [String: Any]) -> [String: Any] {
		var resolved: [String: Any]?
		for (key, value) in params {
			if let dict = value as? [String: Any], let guid = dict["guid"] as? String, let obj = objects[guid] {
				if resolved == nil { resolved = params }
				resolved![key] = obj
			}
		}

		return resolved ?? params
	}

	/// Recursively disposes an object and its children.
	private func disposeObject(_ obj: ChannelOwner, reason: String? = nil) {
		for child in obj.children.values {
			disposeObject(child, reason: reason)
		}

		objects.removeValue(forKey: obj.guid)
		obj.parent?.removeChild(obj)
		obj.emit("close", params: [:])
		obj.dispose()
	}
}
