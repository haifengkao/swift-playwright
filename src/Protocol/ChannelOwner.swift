import Foundation
import Synchronization

/// Base class for all Playwright protocol objects.
///
/// Every remote object (Browser, Page, Frame, etc.) in the Playwright
/// protocol is identified by a GUID and organized in a parent-child
/// hierarchy managed by the server via `__create__` and `__dispose__`
/// messages.
///
/// Subclasses (e.g. `BrowserType`) add typed properties derived from
/// the raw `initializer` dictionary.
///
/// All mutable state is protected by a `Mutex` to ensure thread safety.
/// The `@unchecked Sendable` annotation is required because `ChannelOwner`
/// is a non-final class; all subclasses are `final` and genuinely safe.
///
/// See: https://github.com/microsoft/playwright-python/blob/main/playwright/_impl/_connection.py
public class ChannelOwner: @unchecked Sendable {
	/// The protocol type name (e.g. "Browser", "Page", "BrowserType").
	let type: String

	/// The unique identifier assigned by the server.
	let guid: String

	/// Raw constructor parameters from the server's `__create__` message.
	let initializer: [String: Any]

	/// The connection this object belongs to.
	unowned let connection: Connection

	/// Mutable state protected by a mutex.
	private struct State: ~Copyable {
		var closeSent = false
		var closeEmitted = false
		weak var parent: ChannelOwner?
		var children: [String: ChannelOwner] = [:]
		var eventHandlers: [String: [@Sendable ([String: Any]) -> Void]] = [:]
	}

	private let state: Mutex<State>

	init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		self.guid = guid
		self.type = type
		self.connection = connection
		self.initializer = initializer
		state = Mutex(State(parent: parent))
	}

	/// Called by Connection after the object is created and registered, allowing
	/// subclasses to resolve cross-references to other objects in the registry.
	///
	/// - Parameter resolve: Looks up a registered object by GUID and casts to the expected type.
	func didCreate(resolve _: (String) -> ChannelOwner?) {}

	/// Convenience initializer that derives connection from the parent.
	convenience init(parent: ChannelOwner, type: String, guid: String, initializer: [String: Any]) {
		self.init(connection: parent.connection, parent: parent, type: type, guid: guid, initializer: initializer)
	}

	/// Parent in the object hierarchy.
	var parent: ChannelOwner? {
		state.withLock { $0.parent }
	}

	/// Children in the object hierarchy, keyed by GUID.
	var children: [String: ChannelOwner] {
		state.withLock { $0.children }
	}

	/// Looks up a single child by GUID.
	func child(forGuid guid: String) -> ChannelOwner? {
		state.withLock { $0.children[guid] }
	}

	func setParent(_ newParent: ChannelOwner?) {
		state.withLock { $0.parent = newParent }
	}

	/// Registers an event handler for a specific event name.
	///
	/// Multiple handlers can be registered for the same event — all will
	/// be called in registration order.
	///
	/// - Parameter event: The event name (e.g. `"close"`, `"page"`).
	/// - Parameter handler: The closure to invoke when the event is received.
	func on(_ event: String, handler: @escaping @Sendable ([String: Any]) -> Void) {
		state.withLock { $0.eventHandlers[event, default: []].append(handler) }
	}

	/// Dispatches an event to all registered handlers.
	///
	/// Important: the mutex is released before calling handlers, since
	/// handlers may re-acquire it (e.g. to set `isClosed`) or acquire
	/// mutexes on other objects. `Mutex` is not reentrant.
	///
	/// The `"close"` event is only dispatched once — subsequent calls are
	/// no-ops. This prevents double-firing when `Connection.close()` emits
	/// on objects that already received a server-side close event.
	func emit(_ event: String, params: [String: Any]) {
		let handlers = state.withLock { state in
			if event == "close" {
				guard !state.closeEmitted else {
					return nil as [@Sendable ([String: Any]) -> Void]?
				}

				state.closeEmitted = true
			}

			return state.eventHandlers[event]
		}

		handlers?.forEach { $0(params) }
	}

	func addChild(_ child: ChannelOwner) {
		state.withLock { $0.children[child.guid] = child }
	}

	func removeChild(_ child: ChannelOwner) {
		state.withLock { _ = $0.children.removeValue(forKey: child.guid) }
	}

	/// Severs this object from the tree so the graph can be collected.
	///
	/// Called by the connection during shutdown to break strong reference
	/// cycles between parent ↔ child maps.
	func dispose() {
		state.withLock { state in
			state.parent = nil
			state.children.removeAll()
			state.eventHandlers.removeAll()
		}
	}

	/// Sends a JSON-RPC message to the server targeting this object.
	///
	/// - Parameter method: The RPC method name.
	/// - Parameter params: The parameters to send.
	/// - Returns: The result dictionary from the server response.
	func send(_ method: String, params: sending [String: Any] = [:]) async throws -> sending [String: Any] {
		try await connection.sendMessage(guid: guid, method: method, params: params)
	}

	/// Sends a message without waiting for a response (fire-and-forget).
	func sendNoReply(_ method: String, params: sending [String: Any] = [:]) async {
		await connection.sendNoReply(guid: guid, method: method, params: params)
	}

	/// Sends a `"close"` message to the server, guarding against double-close.
	///
	/// - Returns: `true` if the close was sent, `false` if already closing/closed.
	func sendClose() async throws -> Bool {
		guard state.withLock({ state in
			guard !state.closeSent, !state.closeEmitted else { return false }
			state.closeSent = true
			return true
		}) else { return false }

		_ = try await send("close")
		return true
	}

	/// Sends an RPC call and resolves a typed object from the response.
	///
	/// - Parameter method: The RPC method name.
	/// - Parameter params: The parameters to send.
	/// - Parameter key: The key in the response dict that holds the GUID reference.
	/// - Returns: The resolved object of type `T`.
	func sendAndResolve<T: ChannelOwner>(_ method: String, params: sending [String: Any] = [:], key: String) async throws -> T {
		let result = try await send(method, params: params)

		guard let obj: T = await connection.resolveObject(from: result, key: key) else {
			throw PlaywrightError.serverError("Failed to resolve \(T.self) from '\(key)' in \(method) response")
		}

		return obj
	}

	/// Sends an RPC call and optionally resolves a typed object from the response.
	///
	/// Returns `nil` when the key is missing or the value is null (e.g. `goto` on `about:blank`).
	///
	/// - Parameter method: The RPC method name.
	/// - Parameter params: The parameters to send.
	/// - Parameter key: The key in the response dict that holds the GUID reference.
	/// - Returns: The resolved object, or `nil` if not present.
	func sendAndResolveOptional<T: ChannelOwner>(_ method: String, params: sending [String: Any] = [:], key: String) async throws -> T? {
		let result = try await send(method, params: params)
		return await connection.resolveObject(from: result, key: key)
	}
}
