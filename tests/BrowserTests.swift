import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct BrowserTests {
		@Test("Launched browser has a non-empty version string")
		func launchBrowser() async throws {
			try await withBrowser { browser in
				#expect(!browser.version.isEmpty)
			}
		}

		@Test("browser.isConnected is true after launch")
		func isConnectedAfterLaunch() async throws {
			try await withBrowser { browser in
				#expect(browser.isConnected)
			}
		}

		@Test("browser.close() and playwright.close() both disconnect")
		func closeDisconnects() async throws {
			// Explicit browser.close()
			let pw1 = try await Playwright.launch()
			let browser1 = try await pw1.chromium.launch()
			try await browser1.close()
			#expect(!browser1.isConnected)
			await pw1.close()

			// Cascade via playwright.close()
			let pw2 = try await Playwright.launch()
			let browser2 = try await pw2.chromium.launch()
			await pw2.close()
			#expect(!browser2.isConnected)
		}

		@Test("Multiple browsers can be launched and closed sequentially")
		func multipleBrowsers() async throws {
			let playwright = try await Playwright.launch()

			for _ in 0..<3 {
				let browser = try await playwright.chromium.launch()
				#expect(browser.isConnected)
				try await browser.close()
			}

			await playwright.close()
		}
	}
}
