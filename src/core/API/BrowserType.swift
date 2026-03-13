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
	/// - Parameter headless: Whether to run the browser in headless mode. Defaults to `true`.
	/// - Parameter channel: Browser distribution channel (e.g. `"chrome"`, `"msedge"`).
	/// - Parameter args: Additional arguments to pass to the browser instance.
	/// - Parameter timeout: Maximum time to wait for the browser to start. Defaults to 3 minutes.
	/// - Parameter executablePath: Path to the browser executable.
	/// - Parameter env: Environment variables to set for the browser process.
	/// - Parameter slowMo: Slows down operations by the specified amount.
	/// - Returns: A `Browser` instance.
	/// - Throws: `PlaywrightError` if the browser could not be launched.
	///
	/// See: https://playwright.dev/docs/api/class-browsertype#browser-type-launch
	public func launch(
		headless: Bool? = nil,
		channel: String? = nil,
		args: [String]? = nil,
		timeout: Duration? = nil,
		executablePath: String? = nil,
		env: [String: String]? = nil,
		slowMo: Duration? = nil
	) async throws -> Browser {
		var params: [String: Any] = [
			"timeout": (timeout ?? .seconds(180)).milliseconds,
		]

		if let args { params["args"] = args }
		if let channel { params["channel"] = channel }
		if let headless { params["headless"] = headless }
		if let slowMo { params["slowMo"] = slowMo.milliseconds }
		if let executablePath { params["executablePath"] = executablePath }
		if let env { params["env"] = env.map { ["name": $0.key, "value": $0.value] } }

		let browser: Browser = try await sendAndResolve("launch", params: params, key: "browser")
		browser.browserType = self
		return browser
	}

	/// Launches a browser with a persistent user data directory.
	///
	/// Returns a `BrowserContext` that persists cookies, localStorage, and session
	/// state across runs. Closing the context also closes the underlying browser.
	///
	/// ```swift
	/// let context = try await playwright.chromium.launchPersistentContext(
	///     userDataDir: "/tmp/my-profile"
	/// )
	/// let page = context.pages.first ?? (try await context.newPage())
	/// try await page.goto("https://example.com")
	/// try await context.close()
	/// ```
	///
	/// - Parameter userDataDir: Path to the user data directory.
	/// - Parameter headless: Whether to run the browser in headless mode. Defaults to `true`.
	/// - Parameter channel: Browser distribution channel (e.g. `"chrome"`, `"msedge"`).
	/// - Parameter args: Additional arguments to pass to the browser instance.
	/// - Parameter timeout: Maximum time to wait for the browser to start.
	/// - Parameter executablePath: Path to the browser executable.
	/// - Parameter env: Environment variables to set for the browser process.
	/// - Parameter slowMo: Slows down operations by the specified amount.
	/// - Parameter acceptDownloads: Whether to accept downloads. Defaults to `true`.
	/// - Parameter locale: Browser locale (e.g. `"en-US"`).
	/// - Parameter userAgent: Custom user agent string.
	/// - Returns: A persistent `BrowserContext`.
	/// - Throws: `PlaywrightError` if the browser could not be launched.
	///
	/// See: https://playwright.dev/docs/api/class-browsertype#browser-type-launch-persistent-context
	public func launchPersistentContext(
		userDataDir: String,
		headless: Bool? = nil,
		channel: String? = nil,
		args: [String]? = nil,
		timeout: Duration? = nil,
		executablePath: String? = nil,
		env: [String: String]? = nil,
		slowMo: Duration? = nil,
		acceptDownloads: Bool? = nil,
		locale: String? = nil,
		userAgent: String? = nil
	) async throws -> BrowserContext {
		var params: [String: Any] = [
			"userDataDir": userDataDir,
			"sdkLanguage": Driver.sdkLanguage,
			"timeout": (timeout ?? .seconds(180)).milliseconds,
		]

		if let args { params["args"] = args }
		if let locale { params["locale"] = locale }
		if let channel { params["channel"] = channel }
		if let headless { params["headless"] = headless }
		if let userAgent { params["userAgent"] = userAgent }
		if let slowMo { params["slowMo"] = slowMo.milliseconds }
		if let executablePath { params["executablePath"] = executablePath }
		if let acceptDownloads { params["acceptDownloads"] = acceptDownloads }
		if let env { params["env"] = env.map { ["name": $0.key, "value": $0.value] } }

		return try await sendAndResolve("launchPersistentContext", params: params, key: "context")
	}
}
