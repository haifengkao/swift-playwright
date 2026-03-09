import Testing
import Foundation
@testable import Playwright

struct BrowserTests {
	@Test("BrowserType.launch() returns a Browser instance", .timeLimit(.minutes(1)))
	func launchBrowser() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		#expect(!browser.version.isEmpty)

		try await browser.close()
		await playwright.close()
	}

	@Test("browser.isConnected is true after launch", .timeLimit(.minutes(1)))
	func isConnectedAfterLaunch() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		#expect(browser.isConnected)

		try await browser.close()
		await playwright.close()
	}

	@Test("browser.close() completes without error", .timeLimit(.minutes(1)))
	func closeSucceeds() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		try await browser.close()
		await playwright.close()
	}

	@Test("browser.isConnected is false after close", .timeLimit(.minutes(1)))
	func isConnectedAfterClose() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		try await browser.close()
		#expect(!browser.isConnected)

		await playwright.close()
	}

	@Test("Launch with headless option works", .timeLimit(.minutes(1)))
	func launchHeadless() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch(.init(headless: true))

		#expect(browser.isConnected)

		try await browser.close()
		await playwright.close()
	}

	@Test("browser.isConnected is false after playwright.close()", .timeLimit(.minutes(1)))
	func isConnectedAfterPlaywrightClose() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		await playwright.close()
		#expect(!browser.isConnected)
	}

	@Test("Multiple browsers can be launched and closed sequentially", .timeLimit(.minutes(2)))
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
