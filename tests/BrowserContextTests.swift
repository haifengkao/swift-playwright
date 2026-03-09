import Testing
import Foundation
@testable import Playwright

struct BrowserContextTests {
	@Test("browser.newContext() returns a BrowserContext", .timeLimit(.minutes(1)))
	func newContext() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		let context = try await browser.newContext()
		#expect(context.browser === browser)

		try await context.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("context.close() completes without error", .timeLimit(.minutes(1)))
	func closeSucceeds() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		let context = try await browser.newContext()
		try await context.close()

		try await browser.close()
		await playwright.close()
	}

	@Test("Closed context is removed from browser.contexts", .timeLimit(.minutes(1)))
	func closedContextRemoved() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		let context = try await browser.newContext()
		#expect(browser.contexts.count == 1)

		try await context.close()
		#expect(browser.contexts.isEmpty)

		try await browser.close()
		await playwright.close()
	}

	@Test("Multiple contexts can coexist on one browser", .timeLimit(.minutes(1)))
	func multipleContexts() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		let context1 = try await browser.newContext()
		let context2 = try await browser.newContext()
		#expect(browser.contexts.count == 2)

		try await context1.close()
		try await context2.close()
		try await browser.close()
		await playwright.close()
	}

	@Test("Double-close is idempotent (no error)", .timeLimit(.minutes(1)))
	func doubleClose() async throws {
		let playwright = try await Playwright.launch()
		let browser = try await playwright.chromium.launch()

		let context = try await browser.newContext()
		try await context.close()
		try await context.close() // Should not throw

		try await browser.close()
		await playwright.close()
	}
}
