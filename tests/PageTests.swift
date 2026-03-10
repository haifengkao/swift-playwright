import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct PageTests {
		@Test("context.newPage() returns a Page")
		func newPage() async throws {
			try await withContext { context in
				let page = try await context.newPage()
				#expect(!page.isClosed)
			}
		}

		@Test("New page appears in context.pages")
		func pageInContextPages() async throws {
			try await withContext { context in
				let page = try await context.newPage()
				#expect(context.pages.count == 1)
				#expect(context.pages.first === page)
			}
		}

		@Test("page.url is about:blank for a fresh page")
		func freshPageUrl() async throws {
			try await withPage { page in
				#expect(page.url == "about:blank")
			}
		}

		@Test("page.close() marks page closed and removes from context")
		func closeCleansUp() async throws {
			try await withContext { context in
				let page = try await context.newPage()
				#expect(context.pages.count == 1)

				try await page.close()
				#expect(page.isClosed)
				#expect(context.pages.isEmpty)
			}
		}

		@Test("Multiple pages can coexist in one context")
		func multiplePages() async throws {
			try await withContext { context in
				_ = try await context.newPage()
				_ = try await context.newPage()
				#expect(context.pages.count == 2)
			}
		}

		@Test("page.context references the owning context")
		func pageContext() async throws {
			try await withContext { context in
				let page = try await context.newPage()
				#expect(page.context === context)
			}
		}
	}
}
