import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct E2ETests {
		@Test("Playwright.launch() succeeds and returns instance")
		func launchSucceeds() async throws {
			let playwright = try await Playwright.launch()

			#expect(playwright.chromium.name == "chromium")
			#expect(playwright.firefox.name == "firefox")
			#expect(playwright.webkit.name == "webkit")

			await playwright.close()
		}

		@Test("Browser types have non-empty executable paths")
		func executablePaths() async throws {
			let playwright = try await Playwright.launch()

			#expect(!playwright.chromium.executablePath.isEmpty)
			#expect(!playwright.firefox.executablePath.isEmpty)
			#expect(!playwright.webkit.executablePath.isEmpty)

			await playwright.close()
		}

		@Test("Multiple launch/close cycles work")
		func multipleCycles() async throws {
			for _ in 0..<3 {
				let playwright = try await Playwright.launch()
				#expect(playwright.chromium.name == "chromium")

				// Verify the instance is functional before closing
				let browser = try await playwright.chromium.launch()
				#expect(browser.isConnected)
				try await browser.close()

				await playwright.close()

				// Verify close() actually tore down the connection
				#expect(!browser.isConnected)
			}
		}
	}
}
