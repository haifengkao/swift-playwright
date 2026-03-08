import Foundation

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

	/// Parent in the object hierarchy.
	private(set) weak var parent: ChannelOwner?

	/// Children in the object hierarchy, keyed by GUID.
	private(set) var children: [String: ChannelOwner] = [:]

	init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		self.guid = guid
		self.type = type
		self.parent = parent
		self.connection = connection
		self.initializer = initializer
	}

	func addChild(_ child: ChannelOwner) {
		children[child.guid] = child
	}

	func removeChild(_ child: ChannelOwner) {
		children.removeValue(forKey: child.guid)
	}

	/// Sends a JSON-RPC message to the server targeting this object.
	///
	/// - Parameter method: The RPC method name.
	/// - Parameter params: The parameters to send.
	/// - Returns: The result dictionary from the server response.
	func send(_ method: String, params: sending [String: Any] = [:]) async throws -> sending [String: Any] {
		try await connection.sendMessage(guid: guid, method: method, params: params)
	}
}
