import Foundation

/// Provides methods for simulating keyboard input.
///
/// Access via `page.keyboard`. All methods send commands on the Page channel.
///
/// See: https://playwright.dev/docs/api/class-keyboard
public final class Keyboard: Sendable {
	private let page: Page

	init(_ page: Page) {
		self.page = page
	}

	/// Types text character by character, generating `keydown`, `keypress`, and `keyup` events.
	///
	/// - Parameter text: The text to type.
	/// - Parameter delay: Time to wait between key presses.
	///
	/// See: https://playwright.dev/docs/api/class-keyboard#keyboard-type
	public func type(_ text: String, delay: Duration? = nil) async throws {
		var params: [String: Any] = ["text": text]
		if let delay { params["delay"] = delay.milliseconds }

		_ = try await page.send("keyboardType", params: params)
	}

	/// Presses a key (or key combination like `"Control+A"`).
	///
	/// - Parameter key: The key name (e.g. `"Enter"`, `"Control+A"`, `"a"`).
	/// - Parameter delay: Time to wait between `keydown` and `keyup`.
	///
	/// See: https://playwright.dev/docs/api/class-keyboard#keyboard-press
	public func press(_ key: String, delay: Duration? = nil) async throws {
		var params: [String: Any] = ["key": key]
		if let delay { params["delay"] = delay.milliseconds }

		_ = try await page.send("keyboardPress", params: params)
	}

	/// Dispatches a `keydown` event.
	///
	/// See: https://playwright.dev/docs/api/class-keyboard#keyboard-down
	public func down(_ key: String) async throws {
		_ = try await page.send("keyboardDown", params: ["key": key])
	}

	/// Dispatches a `keyup` event.
	///
	/// See: https://playwright.dev/docs/api/class-keyboard#keyboard-up
	public func up(_ key: String) async throws {
		_ = try await page.send("keyboardUp", params: ["key": key])
	}

	/// Inserts text directly without generating key events.
	///
	/// See: https://playwright.dev/docs/api/class-keyboard#keyboard-insert-text
	public func insertText(_ text: String) async throws {
		_ = try await page.send("keyboardInsertText", params: ["text": text])
	}
}
