import Testing
import Foundation
@testable import Playwright

/// Base suite for all Playwright integration tests.
///
/// Extend with nested `@Suite`s to inherit the shared time limit.
#if CI
@Suite(.timeLimit(.minutes(2)), .serialized)
#else
@Suite(.timeLimit(.minutes(2)))
#endif
struct PlaywrightTests {}

#if canImport(Darwin)
let isApplePlatform = true
#else
let isApplePlatform = false
#endif

/// Resolves a browser name string to the corresponding `BrowserType` instance.
func browserType(named name: String, from playwright: Playwright) -> BrowserType {
	switch name {
		case "chromium": playwright.chromium
		case "firefox": playwright.firefox
		case "webkit": playwright.webkit
		default: fatalError("Unknown browser: \(name)")
	}
}

/// Launches a Playwright server and browser, runs the body, then ensures cleanup.
func withBrowser(browser browserName: String = "chromium", _ body: (Browser) async throws -> Void) async throws {
	let playwright = try await Playwright.launch()
	var caughtError: (any Error)?
	do {
		let browser = try await browserType(named: browserName, from: playwright).launch()
		do {
			try await body(browser)
		} catch {
			caughtError = error
		}
		try? await browser.close()
	} catch {
		if caughtError == nil { caughtError = error }
	}
	await playwright.close()
	if let caughtError { throw caughtError }
}

/// Launches a Playwright server, browser, and context, runs the body, then ensures cleanup.
func withContext(browser browserName: String = "chromium", _ body: (BrowserContext) async throws -> Void) async throws {
	try await withBrowser(browser: browserName) { browser in
		let context = try await browser.newContext()
		var caughtError: (any Error)?
		do {
			try await body(context)
		} catch {
			caughtError = error
		}
		try? await context.close()
		if let caughtError { throw caughtError }
	}
}

/// Launches a Playwright server, browser, and page, runs the body, then ensures cleanup.
func withPage(browser browserName: String = "chromium", _ body: (Page) async throws -> Void) async throws {
	try await withBrowser(browser: browserName) { browser in
		let page = try await browser.newPage()
		var caughtError: (any Error)?
		do {
			try await body(page)
		} catch {
			caughtError = error
		}
		try? await page.close()
		if let caughtError { throw caughtError }
	}
}
