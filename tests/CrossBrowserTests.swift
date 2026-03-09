import Testing
import Foundation
@testable import Playwright

@Suite(.timeLimit(.minutes(2)))
struct CrossBrowserTests {
	private func browserType(named name: String, from playwright: Playwright) -> BrowserType {
		switch name {
			case "webkit": playwright.webkit
			case "firefox": playwright.firefox
			case "chromium": playwright.chromium
			default: fatalError("Unknown browser: \(name)")
		}
	}

	@Test("Launch, newPage, and close works", arguments: ["chromium", "firefox", "webkit"])
	func fullLifecycle(browserName: String) async throws {
		let playwright = try await Playwright.launch()
		let browser = try await browserType(named: browserName, from: playwright).launch()
		#expect(browser.isConnected)
		#expect(!browser.version.isEmpty)

		let page = try await browser.newPage()
		#expect(page.url == "about:blank")
		#expect(!page.isClosed)

		try await page.close()
		#expect(page.isClosed)

		try await browser.close()
		#expect(!browser.isConnected)

		await playwright.close()
	}

	@Test("Multiple pages across contexts", arguments: ["chromium", "firefox", "webkit"])
	func multiplePagesAcrossContexts(browserName: String) async throws {
		let playwright = try await Playwright.launch()
		let browserType = browserType(named: browserName, from: playwright)

		let browser = try await browserType.launch()

		let context1 = try await browser.newContext()
		let context2 = try await browser.newContext()

		let page1 = try await context1.newPage()
		let page2 = try await context2.newPage()

		#expect(context1.pages.count == 1)
		#expect(context2.pages.count == 1)
		#expect(browser.contexts.count == 2)

		try await page1.close()
		try await page2.close()
		try await context1.close()
		try await context2.close()
		try await browser.close()
		await playwright.close()
	}
}
