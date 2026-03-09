import Testing
import Foundation
@testable import Playwright

struct PageTests {
	@Test("context.newPage() returns a Page", .timeLimit(.minutes(1)))
	func newPage() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()
		let context = try await browser.newContext()

		let page = try await context.newPage()
		#expect(!page.isClosed)

		try await page.close()
		try await context.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("New page appears in context.pages", .timeLimit(.minutes(1)))
	func pageInContextPages() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()
		let context = try await browser.newContext()

		let page = try await context.newPage()
		#expect(context.pages.count == 1)
		#expect(context.pages.first === page)

		try await page.close()
		try await context.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("page.url is about:blank for a fresh page", .timeLimit(.minutes(1)))
	func freshPageUrl() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()
		let context = try await browser.newContext()

		let page = try await context.newPage()
		#expect(page.url == "about:blank")

		try await page.close()
		try await context.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("page.close() completes without error", .timeLimit(.minutes(1)))
	func closeSucceeds() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()
		let context = try await browser.newContext()

		let page = try await context.newPage()
		try await page.close()

		try await context.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("page.isClosed is true after close", .timeLimit(.minutes(1)))
	func closedAfterClose() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()
		let context = try await browser.newContext()

		let page = try await context.newPage()
		try await page.close()
		#expect(page.isClosed)

		try await context.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("Closed page is removed from context.pages", .timeLimit(.minutes(1)))
	func closedPageRemoved() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()
		let context = try await browser.newContext()

		let page = try await context.newPage()
		#expect(context.pages.count == 1)

		try await page.close()
		#expect(context.pages.isEmpty)

		try await context.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("Multiple pages can coexist in one context", .timeLimit(.minutes(1)))
	func multiplePages() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()
		let context = try await browser.newContext()

		let page1 = try await context.newPage()
		let page2 = try await context.newPage()
		#expect(context.pages.count == 2)

		try await page1.close()
		try await page2.close()
		try await context.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("page.context references the owning context", .timeLimit(.minutes(1)))
	func pageContext() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()
		let context = try await browser.newContext()

		let page = try await context.newPage()
		#expect(page.context === context)

		try await page.close()
		try await context.close()
		try await browser.close()
		await playwright.close()
	}
}
