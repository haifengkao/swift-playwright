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

		on("close") { [weak self] _ in
			guard let self else { return }
			self.browser?.removeContext(self)
		}

		on("page") { [weak self] params in
			guard let self, let page = params["page"] as? Page else { return }
			self.state.withLock { $0.pages.append(page) }
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
