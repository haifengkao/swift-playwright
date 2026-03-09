import Foundation
import Synchronization

/// Represents a frame within a page (main frame or iframe).
///
/// At minimum, each page has a main frame. The frame tracks the
/// current URL and name.
///
/// See: https://playwright.dev/docs/api/class-frame
public final class Frame: ChannelOwner, @unchecked Sendable {
	/// The frame's name attribute.
	public let name: String

	private struct State: ~Copyable {
		var url: String
	}

	private let state: Mutex<State>

	/// The current URL of the frame.
	public var url: String {
		state.withLock { $0.url }
	}

	func setUrl(_ url: String) {
		state.withLock { $0.url = url }
	}

	override init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		name = initializer["name"] as? String ?? ""
		state = Mutex(State(url: initializer["url"] as? String ?? ""))
		super.init(connection: connection, parent: parent, type: type, guid: guid, initializer: initializer)
	}
}
