import Foundation

/// Main entry point for Playwright browser automation.
///
/// Use ``launch()`` to start a Playwright server and access browser types:
///
/// ```swift
/// let playwright = try await Playwright.launch()
///
/// print(playwright.chromium.name)       // "chromium"
/// print(playwright.firefox.name)        // "firefox"
/// print(playwright.webkit.name)         // "webkit"
///
/// await playwright.close()
/// ```
///
/// See: https://playwright.dev/docs/api/class-playwright
public final class Playwright: Sendable {
	/// The Chromium browser type.
	public let chromium: BrowserType

	/// The Firefox browser type.
	public let firefox: BrowserType

	/// The WebKit browser type.
	public let webkit: BrowserType

	private let connection: Connection

	private init(chromium: BrowserType, firefox: BrowserType, webkit: BrowserType, connection: Connection) {
		self.chromium = chromium
		self.firefox = firefox
		self.webkit = webkit
		self.connection = connection
	}

	/// Launches a Playwright server and initializes the protocol connection.
	///
	/// This starts the Playwright Node.js driver as a subprocess, sends
	/// the `initialize` handshake, and waits for the server to register
	/// all browser types.
	///
	/// - Throws: ``PlaywrightError`` if the driver cannot be found or initialization fails.
	/// - Returns: A fully initialized Playwright instance with access to browser types.
	public static func launch() async throws -> Playwright {
		let connection = try Connection(
			transport: Transport.connect(to: await PlaywrightServer.launch())
		)

		await connection.start()

		do {
			let result = try await connection.sendMessage(guid: "", method: "initialize", params: ["sdkLanguage": Driver.sdkLanguage])

			guard let playwrightObj: ChannelOwner = await connection.resolveObject(from: result, key: "playwright") else {
				throw PlaywrightError.serverError("Failed to initialize: no Playwright object in response")
			}

			/// Resolve browser types from the Playwright object's initializer.
			/// The initializer contains {"chromium": {"guid": "..."}, ...}
			func resolveBrowserType(_ key: String) async throws -> BrowserType {
				guard let obj: BrowserType = await connection.resolveObject(from: playwrightObj.initializer, key: key) else {
					throw PlaywrightError.serverError("Failed to resolve browser type: \(key)")
				}

				return obj
			}

			return try await Playwright(
				chromium: resolveBrowserType("chromium"),
				firefox: resolveBrowserType("firefox"),
				webkit: resolveBrowserType("webkit"),
				connection: connection
			)
		} catch {
			await connection.close()
			throw error
		}
	}

	/// Shuts down the Playwright server and cleans up resources.
	public func close() async {
		await connection.close()
	}
}
