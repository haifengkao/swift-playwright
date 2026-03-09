import Foundation

/// Represents a browser engine type (Chromium, Firefox, or WebKit).
///
/// `BrowserType` provides factory methods for launching browser instances.
/// Access browser types through `Playwright.chromium`, `Playwright.firefox`, or `Playwright.webkit`.
///
/// ```swift
/// let playwright = try await Playwright.launch()
/// let browser = try await playwright.chromium.launch()
/// ```
///
/// See: https://playwright.dev/docs/api/class-browsertype
public final class BrowserType: ChannelOwner, @unchecked Sendable {
	/// The browser engine name: `"chromium"`, `"firefox"`, or `"webkit"`.
	public let name: String

	/// The path to the browser executable.
	public let executablePath: String

	override init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		name = initializer["name"] as? String ?? ""
		executablePath = initializer["executablePath"] as? String ?? ""
		super.init(connection: connection, parent: parent, type: type, guid: guid, initializer: initializer)
	}

	/// Launches a new browser instance.
	///
	/// ```swift
	/// let playwright = try await Playwright.launch()
	/// let browser = try await playwright.chromium.launch()
	/// // ... use browser ...
	/// try await browser.close()
	/// ```
	///
	/// - Parameter options: Launch options (headless, channel, timeout, etc.).
	/// - Returns: A `Browser` instance.
	/// - Throws: `PlaywrightError` if the browser could not be launched.
	///
	/// See: https://playwright.dev/docs/api/class-browsertype#browser-type-launch
	public func launch(_ options: LaunchOptions = .init()) async throws -> Browser {
		try await sendAndResolve("launch", params: options.toProtocol(), key: "browser")
	}
}
