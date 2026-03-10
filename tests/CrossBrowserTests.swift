import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct CrossBrowserTests {
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
			try await withBrowser(browser: browserName) { browser in
				let context1 = try await browser.newContext()
				let context2 = try await browser.newContext()

				_ = try await context1.newPage()
				_ = try await context2.newPage()

				#expect(context1.pages.count == 1)
				#expect(context2.pages.count == 1)
				#expect(browser.contexts.count == 2)
			}
		}

		@Test("Navigation and title work across browsers", arguments: ["chromium", "firefox", "webkit"])
		func navigationCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				let response = try await page.goto("https://example.com")
				#expect(response?.ok == true)
				#expect(page.url.contains("example.com"))

				let title = try await page.title()
				#expect(title == "Example Domain")
			}
		}

		@Test("Locator actions work across browsers", arguments: ["chromium", "firefox", "webkit"])
		func locatorActionsCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("""
						<button onclick="document.title = 'clicked'">Click me</button>
						<input type="text" />
					""")

				try await page.locator("button").click()
				#expect(try await page.title() == "clicked")

				try await page.locator("input").fill("hello")
				#expect(try await page.locator("input").inputValue() == "hello")
			}
		}

		@Test("Evaluate and screenshot work across browsers", arguments: ["chromium", "firefox", "webkit"])
		func evaluateScreenshotCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("<h1>Test</h1>")

				let result = try await page.evaluate("1 + 1")
				#expect(result as? Int == 2)

				let screenshot = try await page.screenshot()
				#expect(!screenshot.isEmpty)
				// PNG magic bytes
				#expect(screenshot[0] == 0x89)
				#expect(screenshot[1] == 0x50) // 'P'
				#expect(screenshot[2] == 0x4E) // 'N'
				#expect(screenshot[3] == 0x47) // 'G'
			}
		}
	}
}
