import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct PersistentContextTests {
		@Test("launchPersistentContext returns a BrowserContext")
		func launchReturnsContext() async throws {
			try await withPersistentContext { context in
				#expect(context.browser != nil)
			}
		}

		@Test("persistent context has a browser reference")
		func browserReference() async throws {
			try await withPersistentContext { context in
				let browser = try #require(context.browser)
				#expect(browser.version.isEmpty == false)
			}
		}

		@Test("persistent context browser has browserType set")
		func browserTypeSet() async throws {
			try await withPersistentContext { context in
				let browser = try #require(context.browser)
				#expect(browser.browserType.name == "chromium")
			}
		}

		@Test("persistent context can create and navigate pages")
		func navigatePages() async throws {
			try await withPersistentContext { context in
				let page: Page
				if let existing = context.pages.first {
					page = existing
				} else {
					page = try await context.newPage()
				}

				try await page.setContent("<h1>Persistent</h1>")

				let element = try #require(try await page.querySelector("h1"))
				let text = try await element.textContent()
				#expect(text == "Persistent")
			}
		}

		@Test("persistent context supports evaluate")
		func evaluateWorks() async throws {
			try await withPersistentContext { context in
				let page: Page
				if let existing = context.pages.first { page = existing }
				else { page = try await context.newPage() }

				let result = try await page.evaluate("1 + 1", as: Int.self)
				#expect(result == 2)
			}
		}

		@Test("persistent context appears in browser.contexts")
		func contextInBrowserContexts() async throws {
			try await withPersistentContext { context in
				let browser = try #require(context.browser)
				#expect(browser.contexts.contains { $0 === context })
			}
		}

		@Test("closing persistent context disconnects browser")
		func closeCleanup() async throws {
			let playwright = try await Playwright.launch()
			let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("pw-test-\(UUID().uuidString)").path
			defer { try? FileManager.default.removeItem(atPath: tmpDir) }

			let context = try await playwright.chromium.launchPersistentContext(userDataDir: tmpDir)
			let browser = try #require(context.browser)
			#expect(browser.isConnected)

			try await context.close()
			#expect(!browser.isConnected)

			await playwright.close()
		}

		@Test("launchPersistentContext with headless option")
		func headlessOption() async throws {
			let playwright = try await Playwright.launch()
			let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("pw-test-\(UUID().uuidString)").path
			defer { try? FileManager.default.removeItem(atPath: tmpDir) }

			let context = try await playwright.chromium.launchPersistentContext(
				userDataDir: tmpDir,
				headless: true
			)
			#expect(context.browser != nil)
			try await context.close()
			await playwright.close()
		}
	}
}
