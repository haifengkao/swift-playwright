import Foundation
import Synchronization

/// An isolated browser context with its own cookies, storage, and session state.
///
/// ```swift
/// let context = try await browser.newContext()
/// let page = try await context.newPage()
/// // ... use page ...
/// try await context.close()
/// ```
///
/// See: https://playwright.dev/docs/api/class-browsercontext
public final class BrowserContext: ChannelOwner, @unchecked Sendable {
	private struct State: ~Copyable {
		var pages: [Page] = []
		var isOwnedContext = false
		var consoleHandlers: [@Sendable (ConsoleMessage) -> Void] = []
	}

	private let state = Mutex(State())

	/// The pages open in this context.
	public var pages: [Page] {
		state.withLock { $0.pages }
	}

	/// The browser that owns this context.
	///
	/// Cached at init time so the reference survives `dispose()` teardown,
	/// matching the same pattern used by `Page.context`.
	public let browser: Browser?

	func setOwned() {
		state.withLock { $0.isOwnedContext = true }
	}

	override init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		browser = parent as? Browser
		super.init(connection: connection, parent: parent, type: type, guid: guid, initializer: initializer)

		browser?.addContext(self)

		on("close") { [weak self] _ in
			guard let self else { return }
			self.state.withLock { $0.consoleHandlers.removeAll() }
			self.browser?.removeContext(self)
		}

		on("page") { [weak self] params in
			guard let self, let page = params["page"] as? Page else { return }
			self.state.withLock { $0.pages.append(page) }
		}

		on("dialog") { params in
			guard let dialog = params["dialog"] as? Dialog, let page = dialog.parent as? Page else { return }
			if dialog.page == nil { dialog.page = page }
			page.dispatchDialog(dialog)
		}

		on("console") { [weak self] params in
			let message = ConsoleMessage(params: params)

			self?.dispatchConsole(message)
			message.page?.dispatchConsole(message)
		}

		// Response events are emitted on the BrowserContext channel server-side
		// (see Playwright's `frames.js: emitOnContext(..., Response, ...)`),
		// then forwarded to the originating page. ``Page.onResponse`` enables the
		// subscription via ``updateSubscription``; this listener routes each
		// event to the matching page's response handlers.
		on("response") { params in
			guard let response = params["response"] as? Response,
			      let page = params["page"] as? Page else { return }
			page.dispatchResponse(response)
		}

		// Request / requestFinished / requestFailed share the same plumbing —
		// emitted on BrowserContext, forwarded to page. Subscription enabled by
		// the matching ``Page.onRequest*`` registration.
		on("request") { params in
			guard let request = params["request"] as? Request,
			      let page = params["page"] as? Page else { return }
			page.dispatchRequest(request)
		}

		on("requestFinished") { params in
			guard let request = params["request"] as? Request,
			      let page = params["page"] as? Page else { return }
			page.dispatchRequestFinished(request)
		}

		on("requestFailed") { params in
			guard let request = params["request"] as? Request,
			      let page = params["page"] as? Page else { return }
			let failureText = params["failureText"] as? String ?? ""
			page.dispatchRequestFailed(request, failureText: failureText)
		}
	}

	/// Creates a new page in this context.
	///
	/// - Returns: A new `Page`.
	/// - Throws: `PlaywrightError` if the page could not be created, or if this
	///   context was created via `browser.newPage()` and already has a page.
	///
	/// See: https://playwright.dev/docs/api/class-browsercontext#browser-context-new-page
	public func newPage() async throws -> Page {
		let hasOwner = state.withLock { $0.isOwnedContext }
		if hasOwner {
			throw PlaywrightError.serverError(
				"Please use browser.newPage() for single-page contexts"
			)
		}

		return try await sendAndResolve("newPage", key: "page")
	}

	// MARK: - Console

	/// Registers a handler for console message events from all pages and workers in this context.
	///
	/// Unlike `Page.onConsole`, this receives console messages from **all** sources,
	/// including service workers whose messages don't have an associated page.
	///
	/// ```swift
	/// await context.onConsole { message in
	///     print("\(message.consoleType): \(message.text)")
	/// }
	/// ```
	///
	/// See: https://playwright.dev/docs/api/class-browsercontext#browser-context-event-console
	public func onConsole(_ handler: @escaping @Sendable (ConsoleMessage) -> Void) async {
		let isFirst = state.withLock { state in
			let wasEmpty = state.consoleHandlers.isEmpty
			state.consoleHandlers.append(handler)
			return wasEmpty
		}

		if isFirst { await sendNoReply("updateSubscription", params: ["event": "console", "enabled": true]) }
	}

	/// Called when a console event is received in this context.
	func dispatchConsole(_ message: ConsoleMessage) {
		let handlers = state.withLock { $0.consoleHandlers }

		for handler in handlers {
			handler(message)
		}
	}

	/// Removes a page from this context's page list.
	func removePage(_ page: Page) {
		state.withLock { $0.pages.removeByIdentity(page) }
	}

	/// Closes this context and all its pages.
	///
	/// See: https://playwright.dev/docs/api/class-browsercontext#browser-context-close
	public func close() async throws {
		_ = try await sendClose()
	}
}
