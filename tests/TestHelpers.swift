import Testing
import Foundation
@testable import Playwright

// Base suite for all Playwright integration tests.
//
// Extend with nested `@Suite`s to inherit the shared time limit.
#if CI && !canImport(Darwin)
@Suite(.timeLimit(.minutes(5)), .serialized)
#else
@Suite(.timeLimit(.minutes(5)))
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

/// Launches a Playwright server with a persistent context, runs the body, then ensures cleanup.
func withPersistentContext(browser browserName: String = "chromium", _ body: (BrowserContext) async throws -> Void) async throws {
	let playwright = try await Playwright.launch()
	let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("pw-test-\(UUID().uuidString)").path
	defer { try? FileManager.default.removeItem(atPath: tmpDir) }

	var caughtError: (any Error)?
	do {
		let context = try await browserType(named: browserName, from: playwright).launchPersistentContext(userDataDir: tmpDir)
		do {
			try await body(context)
		} catch {
			caughtError = error
		}
		try? await context.close()
	} catch {
		if caughtError == nil { caughtError = error }
	}
	await playwright.close()
	if let caughtError { throw caughtError }
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
