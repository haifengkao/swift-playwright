import Testing
import Foundation
@testable import Playwright

struct PlaywrightE2ETests {
	@Test("Playwright.launch() succeeds and returns instance", .timeLimit(.minutes(1)))
	func launchSucceeds() async throws {
		let playwright = try await Playwright.launch()

		#expect(playwright.chromium.name == "chromium")
		#expect(playwright.firefox.name == "firefox")
		#expect(playwright.webkit.name == "webkit")
	}

	@Test("Browser types have non-empty executable paths", .timeLimit(.minutes(1)))
	func executablePaths() async throws {
		let playwright = try await Playwright.launch()

		#expect(!playwright.chromium.executablePath.isEmpty)
		#expect(!playwright.firefox.executablePath.isEmpty)
		#expect(!playwright.webkit.executablePath.isEmpty)
	}

	@Test("Multiple launch/close cycles work", .timeLimit(.minutes(2)))
	func multipleCycles() async throws {
		for _ in 0..<3 {
			let playwright = try await Playwright.launch()
			#expect(playwright.chromium.name == "chromium")
		}
	}
}
