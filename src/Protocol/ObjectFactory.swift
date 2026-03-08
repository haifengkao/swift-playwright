import Foundation

/// Maps Playwright protocol type strings to Swift classes.
///
/// When the server sends a `__create__` message, the factory instantiates
/// the appropriate `ChannelOwner` subclass based on the type string.
/// Unknown types produce a plain `ChannelOwner` (no crash).
///
/// See: https://github.com/microsoft/playwright-python/blob/main/playwright/_impl/_object_factory.py
enum ObjectFactory {
	static func create(parent: ChannelOwner, type: String, guid: String, initializer: [String: Any]) -> ChannelOwner {
		switch type {
			case "BrowserType": BrowserType(connection: parent.connection, parent: parent, type: type, guid: guid, initializer: initializer)
			default: ChannelOwner(connection: parent.connection, parent: parent, type: type, guid: guid, initializer: initializer)
		}
	}
}
