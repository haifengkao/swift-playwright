import Testing
import Foundation
@testable import Playwright

/// Tests for close idempotency and cascade behavior across the object lifecycle.
///
/// These cover edge cases where objects are closed out of order or accessed
/// after their parent has already been torn down.
extension PlaywrightTests {
	@Suite struct LifecycleTests {
		// MARK: - Close after playwright.close()

		@Test("browser.close() after playwright.close() does not throw")
		func browserCloseAfterPlaywrightClose() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()

			await playwright.close()
			try await browser.close() // should be a no-op, not throw
			#expect(!browser.isConnected)
		}

		@Test("context.close() after playwright.close() does not throw")
		func contextCloseAfterPlaywrightClose() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			let context = try await browser.newContext()

			await playwright.close()
			try await context.close()
		}

		@Test("page.close() after playwright.close() does not throw")
		func pageCloseAfterPlaywrightClose() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			let page = try await browser.newPage()

			await playwright.close()
			try await page.close()
		}

		// MARK: - Close after browser.close()

		@Test("context.close() after browser.close() does not throw")
		func contextCloseAfterBrowserClose() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			let context = try await browser.newContext()

			try await browser.close()
			try await context.close()

			await playwright.close()
		}

		@Test("page.close() after browser.close() does not throw")
		func pageCloseAfterBrowserClose() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			let page = try await browser.newPage()

			try await browser.close()
			try await page.close()

			await playwright.close()
		}

		// MARK: - Close cascades

		@Test("browser.close() marks pages as closed")
		func browserCloseMarksPagesClosed() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			let page = try await browser.newPage()
			#expect(!page.isClosed)

			try await browser.close()
			#expect(page.isClosed)

			await playwright.close()
		}

		@Test("browser.close() empties browser.contexts")
		func browserCloseEmptiesContexts() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			_ = try await browser.newContext()
			_ = try await browser.newContext()
			#expect(browser.contexts.count == 2)

			try await browser.close()
			#expect(browser.contexts.isEmpty)

			await playwright.close()
		}

		// MARK: - References remain valid after close

		@Test("page.context still returns the owning context after page.close()")
		func pageContextAfterClose() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			let context = try await browser.newContext()
			let page = try await context.newPage()

			let contextBefore = page.context
			try await page.close()
			let contextAfter = page.context

			#expect(contextAfter === contextBefore)
			#expect(contextAfter === context)

			try await context.close()
			try await browser.close()
			await playwright.close()
		}

		@Test("page.context still returns the owning context after playwright.close()")
		func pageContextAfterPlaywrightClose() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			let context = try await browser.newContext()
			let page = try await context.newPage()

			await playwright.close()

			#expect(page.context === context)
		}

		@Test("context.browser still returns the owning browser after context.close()")
		func contextBrowserAfterClose() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			let context = try await browser.newContext()

			let browserBefore = context.browser
			try await context.close()
			let browserAfter = context.browser

			#expect(browserAfter === browserBefore)
			#expect(browserAfter === browser)

			try await browser.close()
			await playwright.close()
		}

		@Test("context.browser still returns the owning browser after playwright.close()")
		func contextBrowserAfterPlaywrightClose() async throws {
			let playwright = try await Playwright.launch()
			let browser = try await playwright.chromium.launch()
			let context = try await browser.newContext()

			await playwright.close()

			#expect(context.browser === browser)
		}
	}
}
