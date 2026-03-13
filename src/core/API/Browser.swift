import Foundation
import Synchronization

/// A browser instance launched by `BrowserType.launch()`.
///
/// ```swift
/// let playwright = try await Playwright.launch()
/// let browser = try await playwright.chromium.launch()
///
/// print(browser.version) // e.g. "131.0.6778.33"
/// print(browser.isConnected) // true
///
/// try await browser.close()
/// ```
///
/// See: https://playwright.dev/docs/api/class-browser
public final class Browser: ChannelOwner, @unchecked Sendable {
	/// The browser version string (e.g. `"131.0.6778.33"`).
	public let version: String

	private struct State: ~Copyable {
		var isConnected = true
		var contexts: [BrowserContext] = []
	}

	private let state = Mutex(State())

	/// Whether the browser is still connected to the server.
	public var isConnected: Bool {
		state.withLock { $0.isConnected }
	}

	/// The browser contexts belonging to this browser.
	public var contexts: [BrowserContext] {
		state.withLock { $0.contexts }
	}

	override init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		version = initializer["version"] as? String ?? ""
		super.init(connection: connection, parent: parent, type: type, guid: guid, initializer: initializer)

		on("close") { [weak self] _ in
			self?.state.withLock { $0.isConnected = false }
		}
	}

	/// Creates a new browser context with default settings.
	///
	/// Each context has its own cookie jar, session storage, and other browser state.
	///
	/// - Returns: A new `BrowserContext`.
	/// - Throws: `PlaywrightError` if the context could not be created.
	///
	/// See: https://playwright.dev/docs/api/class-browser#browser-new-context
	public func newContext() async throws -> BrowserContext {
		try await sendAndResolve("newContext", key: "context")
	}

	/// Creates a new page in a new browser context (convenience shorthand).
	///
	/// The page owns its context — closing the page also closes the context.
	/// The owned context cannot be used to create additional pages.
	///
	/// - Returns: A new `Page`.
	/// - Throws: `PlaywrightError` if the page could not be created.
	///
	/// See: https://playwright.dev/docs/api/class-browser#browser-new-page
	public func newPage() async throws -> Page {
		let context = try await newContext()

		let page: Page
		do {
			page = try await context.newPage()
		} catch {
			try? await context.close()
			throw error
		}

		page.setOwnedContext(context)
		context.setOwned()

		return page
	}

	/// Adds a context to this browser's context list.
	func addContext(_ context: BrowserContext) {
		state.withLock { $0.contexts.append(context) }
	}

	/// Removes a context from this browser's context list.
	func removeContext(_ context: BrowserContext) {
		state.withLock { $0.contexts.removeByIdentity(context) }
	}

	/// Closes the browser and all of its pages.
	///
	/// See: https://playwright.dev/docs/api/class-browser#browser-close
	public func close() async throws {
		_ = try await sendClose()
	}
}
