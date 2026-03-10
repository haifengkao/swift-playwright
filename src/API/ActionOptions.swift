import Foundation

/// Mouse buttons for click actions.
public enum MouseButton: String, Sendable {
	case left, right, middle
}

/// Keyboard modifier keys.
public enum KeyboardModifier: String, Sendable {
	case alt = "Alt"
	case meta = "Meta"
	case shift = "Shift"
	case control = "Control"
}

/// A point position (x, y coordinates).
public struct Position: Sendable {
	public var x: Double
	public var y: Double

	public init(x: Double, y: Double) {
		self.x = x
		self.y = y
	}

	func toParams() -> [String: Any] {
		["x": x, "y": y]
	}
}

/// Element state to wait for in `waitForSelector`.
///
/// See: https://playwright.dev/docs/api/class-frame#frame-wait-for-selector
public enum WaitForSelectorState: String, Sendable {
	case attached, detached, visible, hidden
}

/// Image format for screenshots.
public enum ImageType: String, Sendable {
	case png, jpeg
}
