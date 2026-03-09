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
public final class Page: ChannelOwner, @unchecked Sendable {
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

		on("close") { [weak self] _ in
			guard let self else { return }
			self.state.withLock { $0.isClosed = true }
			self.context.removePage(self)
		}
	}

	/// Closes the page.
	///
	/// If this page was created via `browser.newPage()`, closing it also
	/// closes the owned browser context.
	///
	/// See: https://playwright.dev/docs/api/class-page#page-close
	public func close() async throws {
		let ownedCtx = state.withLock { $0.ownedContext }
		if let ownedCtx {
			try await ownedCtx.close()
		} else {
			_ = try await sendClose()
		}
	}
}
