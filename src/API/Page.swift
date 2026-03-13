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
	package let mainFrame: Frame

	/// Keyboard input API.
	///
	/// See: https://playwright.dev/docs/api/class-keyboard
	public private(set) var keyboard: Keyboard!

	/// Mouse input API.
	///
	/// See: https://playwright.dev/docs/api/class-mouse
	public private(set) var mouse: Mouse!

	/// The browser context that owns this page.
	///
	/// Every page belongs to exactly one context — the parent in the protocol
	/// object tree is always the `BrowserContext` that created it.
	/// Strong reference: the close handlers break the retain cycle by removing
	/// the page from `context.pages`.
	public let context: BrowserContext

	private struct RouteHandler {
		let pattern: String
		let regex: NSRegularExpression
		let handler: @Sendable (Route) async throws -> Void
	}

	private struct State: ~Copyable {
		var isClosed = false
		var ownedContext: BrowserContext?
		var routeHandlers: [RouteHandler] = []
		var dialogHandlers: [@Sendable (Dialog) async -> Void] = []
		var consoleHandlers: [@Sendable (ConsoleMessage) -> Void] = []
		var downloadHandlers: [@Sendable (Download) async -> Void] = []
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

		mouse = Mouse(self)
		mainFrame.page = self
		keyboard = Keyboard(self)

		on("close") { [weak self] _ in
			guard let self else { return }
			self.state.withLock {
				$0.isClosed = true
				$0.routeHandlers.removeAll()
				$0.dialogHandlers.removeAll()
				$0.consoleHandlers.removeAll()
				$0.downloadHandlers.removeAll()
			}
			self.context.removePage(self)
		}

		on("route") { [weak self] params in
			guard let self, let route = params["route"] as? Route else { return }
			self.dispatchRoute(route)
		}

		on("download") { [weak self] params in
			guard let self,
			      let url = params["url"] as? String,
			      let artifact = params["artifact"] as? Artifact,
			      let suggestedFilename = params["suggestedFilename"] as? String
			else { return }
			self.dispatchDownload(Download(url: url, suggestedFilename: suggestedFilename, artifact: artifact))
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

	// MARK: - Events

	/// Registers a handler for dialog events (alert, confirm, prompt, beforeunload).
	///
	/// If no handler is registered, dialogs are auto-dismissed.
	///
	/// ```swift
	/// await page.onDialog { dialog in
	///     print(dialog.message)
	///     try await dialog.accept()
	/// }
	/// ```
	///
	/// See: https://playwright.dev/docs/api/class-page#page-event-dialog
	public func onDialog(_ handler: @escaping @Sendable (Dialog) async -> Void) async {
		let isFirst = state.withLock { state in
			let wasEmpty = state.dialogHandlers.isEmpty
			state.dialogHandlers.append(handler)
			return wasEmpty
		}

		if isFirst { await sendNoReply("updateSubscription", params: ["event": "dialog", "enabled": true]) }
	}

	/// Called by BrowserContext when a dialog event is received for this page.
	func dispatchDialog(_ dialog: Dialog) {
		let handlers = state.withLock { $0.dialogHandlers }
		if handlers.isEmpty {
			// Auto-dismiss: accept for beforeunload, dismiss for others
			Task<Void, Never> {
				if dialog.dialogType == .beforeunload {
					try? await dialog.accept()
				} else {
					try? await dialog.dismiss()
				}
			}
		} else {
			for handler in handlers {
				Task<Void, Never> { await handler(dialog) }
			}
		}
	}

	// MARK: - Downloads

	/// Registers a handler for download events.
	///
	/// Downloads are triggered by page actions (e.g., clicking a link with a `download` attribute).
	///
	/// ```swift
	/// page.onDownload { download in
	///     print(download.suggestedFilename)
	///     try await download.saveAs("/tmp/\(download.suggestedFilename)")
	/// }
	/// ```
	///
	/// See: https://playwright.dev/docs/api/class-page#page-event-download
	public func onDownload(_ handler: @escaping @Sendable (Download) async -> Void) {
		state.withLock { $0.downloadHandlers.append(handler) }
	}

	/// Called when a download event is received for this page.
	func dispatchDownload(_ download: Download) {
		let handlers = state.withLock { $0.downloadHandlers }
		for handler in handlers {
			Task<Void, Never> { await handler(download) }
		}
	}

	// MARK: - Console

	/// Registers a handler for console message events.
	///
	/// ```swift
	/// page.onConsole { message in
	///     print("\(message.consoleType): \(message.text)")
	/// }
	/// ```
	///
	/// See: https://playwright.dev/docs/api/class-page#page-event-console
	public func onConsole(_ handler: @escaping @Sendable (ConsoleMessage) -> Void) async {
		let isFirst = state.withLock { state in
			let wasEmpty = state.consoleHandlers.isEmpty
			state.consoleHandlers.append(handler)
			return wasEmpty
		}

		if isFirst { await sendNoReply("updateSubscription", params: ["event": "console", "enabled": true]) }
	}

	/// Called when a console event is received for this page.
	func dispatchConsole(_ message: ConsoleMessage) {
		let handlers = state.withLock { $0.consoleHandlers }

		for handler in handlers {
			handler(message)
		}
	}

	// MARK: - Routing

	/// Registers a handler to intercept network requests matching the given URL pattern.
	///
	/// ```swift
	/// try await page.route("**/*.png") { route in
	///     try await route.abort()
	/// }
	/// ```
	///
	/// See: https://playwright.dev/docs/api/class-page#page-route
	public func route(_ url: String, handler: @escaping @Sendable (Route) async throws -> Void) async throws {
		let regex = try NSRegularExpression(pattern: Self.globToRegex(url))
		state.withLock { $0.routeHandlers.append(RouteHandler(pattern: url, regex: regex, handler: handler)) }
		try await updateInterceptionPatterns()
	}

	/// Removes a previously registered route handler for the given URL pattern.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-unroute
	public func unroute(_ url: String) async throws {
		state.withLock { $0.routeHandlers.removeAll { $0.pattern == url } }
		try await updateInterceptionPatterns()
	}

	private func updateInterceptionPatterns() async throws {
		let patterns = state.withLock { $0.routeHandlers.map { ["glob": $0.pattern] } }
		_ = try await send("setNetworkInterceptionPatterns", params: ["patterns": patterns])
	}

	/// Called when a route event is received for this page.
	func dispatchRoute(_ route: Route) {
		let handlers = state.withLock { $0.routeHandlers }
		let url = route.request?.url ?? ""

		// Iterate in reverse so later-registered routes take precedence (matching Playwright behavior)
		for h in handlers.reversed() {
			if globMatches(regex: h.regex, url: url) {
				Task<Void, Never> { [handler = h.handler] in
					do { try await handler(route) }
					catch { try? await route.abort() }
				}
				return
			}
		}

		// No matching handler — let the request through
		Task<Void, Never> { try? await route.continue_() }
	}

	/// Matches a precompiled glob regex against a URL.
	private func globMatches(regex: NSRegularExpression, url: String) -> Bool {
		regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil
	}

	/// Converts a Playwright glob pattern to a regex string.
	///
	/// Ported from Playwright's canonical TypeScript implementation in
	/// `playwright-core/src/utils/isomorphic/urlMatch.ts`.
	///
	/// Supports `*` (any chars except `/`), `**` (any chars including `/`),
	/// `{a,b}` alternation groups, and `\` escaping. `?` is treated as a
	/// literal character (not a wildcard). `[…]` is treated as literal.
	static func globToRegex(_ glob: String) -> String {
		var tokens = ["^"]
		var inGroup = false
		var i = glob.startIndex
		let escapedChars: Set<Character> = ["$", "^", "+", ".", "*", "(", ")", "|", "\\", "?", "{", "}", "[", "]"]

		while i < glob.endIndex {
			let c = glob[i]

			// Backslash escaping
			if c == "\\" {
				let next = glob.index(after: i)
				if next < glob.endIndex {
					let char = glob[next]
					tokens.append(escapedChars.contains(char) ? "\\\(char)" : String(char))
					i = glob.index(after: next)
					continue
				}
			}

			// Star handling
			if c == "*" {
				let charBefore: Character? = i > glob.startIndex ? glob[glob.index(before: i)] : nil
				var starCount = 1
				var j = glob.index(after: i)
				while j < glob.endIndex && glob[j] == "*" {
					starCount += 1
					j = glob.index(after: j)
				}
				i = glob.index(before: j) // i now points at the last *

				if starCount > 1 {
					let nextIdx = glob.index(after: i)
					let charAfter: Character? = nextIdx < glob.endIndex ? glob[nextIdx] : nil
					if charAfter == "/" {
						if charBefore == "/" { tokens.append("((.+/)|)") }
						else { tokens.append("(.*/)") }

						i = glob.index(after: nextIdx)
					} else {
						tokens.append("(.*)")
						i = glob.index(after: i)
					}
				} else {
					tokens.append("([^/]*)")
					i = glob.index(after: i)
				}
				continue
			}

			switch c {
				case ",": tokens.append(inGroup ? "|" : "\\,")
				case "{":
					inGroup = true
					tokens.append("(")
				case "}":
					inGroup = false
					tokens.append(")")
				default: tokens.append(escapedChars.contains(c) ? "\\\(c)" : String(c))
			}

			i = glob.index(after: i)
		}

		tokens.append("$")
		return tokens.joined()
	}

	// MARK: - Element Queries

	/// Returns the first element matching the selector, or `nil` if no elements match.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-query-selector
	public func querySelector(_ selector: String, strict: Bool? = nil) async throws -> ElementHandle? {
		try await mainFrame.querySelector(selector, strict: strict)
	}

	/// Returns all elements matching the selector.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-query-selector-all
	public func querySelectorAll(_ selector: String) async throws -> [ElementHandle] {
		try await mainFrame.querySelectorAll(selector)
	}

	/// Waits for an element matching the selector to appear in the DOM.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-wait-for-selector
	public func waitForSelector(_ selector: String, state: WaitForSelectorState = .visible, strict: Bool = false, timeout: Duration? = nil) async throws -> ElementHandle? {
		try await mainFrame.waitForSelector(selector, state: state, strict: strict, timeout: timeout)
	}

	/// Waits for the given duration (protocol-level sleep).
	///
	/// See: https://playwright.dev/docs/api/class-page#page-wait-for-timeout
	public func waitForTimeout(_ timeout: Duration) async throws {
		try await mainFrame.waitForTimeout(timeout)
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
