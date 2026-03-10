import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct BrowserNewPageTests {
		@Test("browser.newPage() returns a Page with url about:blank")
		func newPage() async throws {
			try await withBrowser { browser in
				let page = try await browser.newPage()
				#expect(page.url == "about:blank")
			}
		}

		@Test("browser.newPage() page close also closes owned context")
		func closeOwnedContext() async throws {
			try await withBrowser { browser in
				let page = try await browser.newPage()
				#expect(browser.contexts.count == 1)

				try await page.close()
				#expect(browser.contexts.isEmpty)
			}
		}

		@Test("Calling context.newPage() on owned context throws serverError")
		func ownedContextNewPageThrows() async throws {
			try await withBrowser { browser in
				let page = try await browser.newPage()
				let context = page.context

				await #expect {
					_ = try await context.newPage()
				} throws: { error in
					guard case let PlaywrightError.serverError(message) = error else { return false }
					return message.contains("browser.newPage()")
				}
			}
		}
	}
}
