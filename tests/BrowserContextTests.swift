import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct BrowserContextTests {
		@Test("newContext().browser references the creating browser")
		func newContext() async throws {
			try await withBrowser { browser in
				let context = try await browser.newContext()
				#expect(context.browser === browser)
			}
		}

		@Test("context.close() removes context from browser.contexts")
		func closeRemovesFromBrowser() async throws {
			try await withBrowser { browser in
				let context = try await browser.newContext()
				#expect(browser.contexts.count == 1)

				try await context.close()
				#expect(browser.contexts.isEmpty)
			}
		}

		@Test("Multiple contexts can coexist on one browser")
		func multipleContexts() async throws {
			try await withBrowser { browser in
				_ = try await browser.newContext()
				_ = try await browser.newContext()
				#expect(browser.contexts.count == 2)
			}
		}

		@Test("Double-close is idempotent (no error)")
		func doubleClose() async throws {
			try await withBrowser { browser in
				let context = try await browser.newContext()
				#expect(browser.contexts.count == 1)

				try await context.close()
				#expect(browser.contexts.isEmpty)

				try await context.close() // Should not throw
				#expect(browser.contexts.isEmpty, "Second close should not corrupt contexts list")
			}
		}
	}
}
