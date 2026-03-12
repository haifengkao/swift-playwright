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
			case "Page": Page(parent: parent, type: type, guid: guid, initializer: initializer)
			case "Frame": Frame(parent: parent, type: type, guid: guid, initializer: initializer)
			case "Route": Route(parent: parent, type: type, guid: guid, initializer: initializer)
			case "Dialog": Dialog(parent: parent, type: type, guid: guid, initializer: initializer)
			case "Browser": Browser(parent: parent, type: type, guid: guid, initializer: initializer)
			case "Request": Request(parent: parent, type: type, guid: guid, initializer: initializer)
			case "Response": Response(parent: parent, type: type, guid: guid, initializer: initializer)
			case "Artifact": Artifact(parent: parent, type: type, guid: guid, initializer: initializer)
			case "BrowserType": BrowserType(parent: parent, type: type, guid: guid, initializer: initializer)
			case "ElementHandle": ElementHandle(parent: parent, type: type, guid: guid, initializer: initializer)
			case "BrowserContext": BrowserContext(parent: parent, type: type, guid: guid, initializer: initializer)
			default: ChannelOwner(parent: parent, type: type, guid: guid, initializer: initializer)
		}
	}
}
