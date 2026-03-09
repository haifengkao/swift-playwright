import Testing
import Foundation
@testable import Playwright

struct BrowserNewPageTests {
	@Test("browser.newPage() returns a Page with url about:blank", .timeLimit(.minutes(1)))
	func newPage() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		let page = try await browser.newPage()
		#expect(page.url == "about:blank")

		try await page.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("browser.newPage() page close also closes owned context", .timeLimit(.minutes(1)))
	func closeOwnedContext() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		let page = try await browser.newPage()
		#expect(browser.contexts.count == 1)

		try await page.close()
		#expect(browser.contexts.isEmpty)

		try await browser.close()
		await playwright.close()
	}

	@Test("Calling context.newPage() on owned context throws error", .timeLimit(.minutes(1)))
	func ownedContextNewPageThrows() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		let page = try await browser.newPage()
		let context = page.context

		await #expect(throws: PlaywrightError.self) {
			_ = try await context.newPage()
		}

		try await page.close()
		try await browser.close()
		await playwright.close()
	}
}
