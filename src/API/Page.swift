import Foundation
import Synchronization

/// A single page (tab) within a browser context.
///
/// ```swift
/// let page = try await context.newPage()
/// print(page.url) // "about:blank"
/// try await page.close()
/// ```
///
/// See: https://playwright.dev/docs/api/class-page
public final class Page: ChannelOwner, LocatorFactory, @unchecked Sendable {
	/// The main frame of the page.
	private let mainFrame: Frame

	/// The browser context that owns this page.
	///
	/// Every page belongs to exactly one context — the parent in the protocol
	/// object tree is always the `BrowserContext` that created it.
	/// Strong reference: the close handlers break the retain cycle by removing
	/// the page from `context.pages`.
	public let context: BrowserContext

	private struct State: ~Copyable {
		var isClosed = false
		var ownedContext: BrowserContext?
	}

	private let state = Mutex(State())

	/// The current URL of the page (delegates to main frame).
	public var url: String { mainFrame.url }

	/// Whether the page has been closed.
	public var isClosed: Bool {
		state.withLock { $0.isClosed }
	}

	func setOwnedContext(_ context: BrowserContext) {
		state.withLock { $0.ownedContext = context }
	}

	override init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		// The parent in the object tree is always the BrowserContext.
		// The main frame is already created and referenced by GUID in the initializer.
		// At init time we're inside Connection.dispatch(), so we can't await — but
		// the parent (context) already has the frame as a child object.
		guard
			let ctx = parent as? BrowserContext,
			let frameRef = initializer["mainFrame"] as? [String: Any],
			let frameGuid = frameRef["guid"] as? String,
			let frame = ctx.child(forGuid: frameGuid) as? Frame
		else {
			fatalError("Page created without a valid BrowserContext parent or mainFrame — protocol violation")
		}

		context = ctx
		mainFrame = frame

		super.init(connection: connection, parent: parent, type: type, guid: guid, initializer: initializer)

		mainFrame.page = self

		on("close") { [weak self] _ in
			guard let self else { return }
			self.state.withLock { $0.isClosed = true }
			self.context.removePage(self)
		}
	}

	// MARK: - Locators

	/// Creates a locator for elements matching the given CSS or Playwright selector.
	///
	/// ```swift
	/// let button = page.locator("button.submit")
	/// try await button.click()
	/// ```
	///
	/// See: https://playwright.dev/docs/api/class-page#page-locator
	public func locator(_ selector: String) -> Locator {
		mainFrame.locator(selector)
	}

	// MARK: - Navigation

	/// Navigates the page to the specified URL.
	///
	/// ```swift
	/// let response = try await page.goto("https://example.com")
	/// print(response?.status) // 200
	/// ```
	///
	/// - Parameter url: The URL to navigate to.
	/// - Parameter timeout: Maximum time to wait. Defaults to 30 seconds.
	/// - Parameter waitUntil: When to consider the operation as finished.
	/// - Parameter referer: Referer header to set for navigation.
	/// - Returns: The main resource response, or `nil` for data URLs and `about:blank`.
	/// - Throws: `PlaywrightError` if navigation fails or times out.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-goto
	@discardableResult
	public func goto(_ url: String, timeout: Duration? = nil, waitUntil: WaitUntilState? = nil, referer: String? = nil) async throws -> Response? {
		try await mainFrame.goto(url, timeout: timeout, waitUntil: waitUntil, referer: referer)
	}

	/// Reloads the current page.
	///
	/// - Parameter timeout: Maximum time to wait. Defaults to 30 seconds.
	/// - Parameter waitUntil: When to consider the operation as finished.
	/// - Returns: The main resource response, or `nil`.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-reload
	public func reload(timeout: Duration? = nil, waitUntil: WaitUntilState? = nil) async throws -> Response? {
		try await navigateWithResponse("reload", timeout: timeout, waitUntil: waitUntil)
	}

	/// Navigates back in history.
	///
	/// - Parameter timeout: Maximum time to wait. Defaults to 30 seconds.
	/// - Parameter waitUntil: When to consider the operation as finished.
	/// - Returns: The main resource response, or `nil`.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-go-back
	public func goBack(timeout: Duration? = nil, waitUntil: WaitUntilState? = nil) async throws -> Response? {
		try await navigateWithResponse("goBack", timeout: timeout, waitUntil: waitUntil)
	}

	/// Navigates forward in history.
	///
	/// - Parameter timeout: Maximum time to wait. Defaults to 30 seconds.
	/// - Parameter waitUntil: When to consider the operation as finished.
	/// - Returns: The main resource response, or `nil`.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-go-forward
	public func goForward(timeout: Duration? = nil, waitUntil: WaitUntilState? = nil) async throws -> Response? {
		try await navigateWithResponse("goForward", timeout: timeout, waitUntil: waitUntil)
	}

	private func navigateWithResponse(_ method: String, timeout: Duration? = nil, waitUntil: WaitUntilState? = nil) async throws -> Response? {
		var params: [String: Any] = ["timeout": timeoutMs(timeout)]
		if let waitUntil { params["waitUntil"] = waitUntil.rawValue }

		return try await sendAndResolveOptional(method, params: params, key: "response")
	}

	/// Returns the page title.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-title
	public func title() async throws -> String {
		try await mainFrame.title()
	}

	/// Returns the full HTML content of the page, including the doctype.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-content
	public func content() async throws -> String {
		try await mainFrame.content()
	}

	/// Sets the HTML content of the page.
	///
	/// - Parameter html: The HTML markup to set.
	/// - Parameter timeout: Maximum time to wait. Defaults to 30 seconds.
	/// - Parameter waitUntil: When to consider the operation as finished.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-set-content
	public func setContent(_ html: String, timeout: Duration? = nil, waitUntil: WaitUntilState? = nil) async throws {
		try await mainFrame.setContent(html, timeout: timeout, waitUntil: waitUntil)
	}

	// MARK: - Evaluate

	/// Evaluates a JavaScript expression in the page's main frame.
	///
	/// ```swift
	/// let count: Int = try await page.evaluate("1 + 1")
	/// print(count) // 2
	/// ```
	/// - Parameter expression: The JavaScript expression to evaluate.
	/// - Parameter arg: Optional argument to pass to the expression.
	/// - Returns: The result of the evaluation, or `nil` for JavaScript `null`/`undefined`.
	/// - Throws: `PlaywrightError.invalidArgument` if the result cannot be cast to `T`.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-evaluate
	public func evaluate<T>(_ expression: String, arg: Any? = nil) async throws -> T {
		try await mainFrame.evaluate(expression, arg: arg)
	}

	/// Evaluates a JavaScript expression in the page's main frame.
	///
	/// ```swift
	/// let result = try await page.evaluate("1 + 1")
	/// print(result) // 2
	/// ```
	///
	/// - Parameter expression: The JavaScript expression to evaluate.
	/// - Parameter arg: Optional argument to pass to the expression.
	/// - Returns: The result of the evaluation, or `nil` for JavaScript `null`/`undefined`.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-evaluate
	@_disfavoredOverload
	public func evaluate(_ expression: String, arg: Any? = nil) async throws -> Any? {
		try await mainFrame.evaluate(expression, arg: arg)
	}

	// MARK: - Screenshot

	/// Captures a screenshot of the page.
	///
	/// ```swift
	/// let data = try await page.screenshot()
	/// try data.write(to: URL(fileURLWithPath: "screenshot.png"))
	/// ```
	///
	/// - Parameter fullPage: Whether to capture the full scrollable page. Defaults to false.
	/// - Returns: The screenshot image data.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-screenshot
	public func screenshot(
		fullPage: Bool = false, type: ImageType? = nil, quality: Int? = nil,
		omitBackground: Bool? = nil, timeout: Duration? = nil, path: String? = nil
	) async throws -> Data {
		var params = try screenshotParams(type: type, quality: quality, omitBackground: omitBackground, timeout: timeout, path: path)
		if fullPage { params["fullPage"] = true }

		let result = try await send("screenshot", params: params)
		return try processScreenshotResult(result, path: path)
	}

	// MARK: - Lifecycle

	/// Closes the page.
	///
	/// If this page was created via `browser.newPage()`, closing it also
	/// closes the owned browser context.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-close
	public func close() async throws {
		let ownedCtx = state.withLock { $0.ownedContext }

		if let ownedCtx { try await ownedCtx.close() }
		else { _ = try await sendClose() }
	}
}

extension Page: CustomStringConvertible {
	public var description: String {
		"Page(\(url))"
	}
}
