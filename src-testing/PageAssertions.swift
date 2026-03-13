import Testing
import Playwright

/// Builder for asserting on page-level properties (title, URL).
///
/// Created via `expect(page)`. All assertions are server-side with auto-retry.
///
/// ```swift
/// try await expect(page).toHaveTitle("Example Domain")
/// try await expect(page).toHaveURL("https://example.com/")
/// ```
public struct PageAssertions: Sendable {
	let page: Page
	let isNot: Bool
	let message: String?
	let sourceLocation: SourceLocation

	/// Returns a negated assertion builder.
	///
	/// ```swift
	/// try await expect(page).not.toHaveTitle("Wrong Title")
	/// ```
	public var not: PageAssertions {
		PageAssertions(page: page, isNot: !isNot, message: message, sourceLocation: sourceLocation)
	}

	/// Asserts that the page has the expected title.
	///
	/// See: https://playwright.dev/docs/api/class-pageassertions#page-assertions-to-have-title
	public func toHaveTitle(_ expected: String, ignoreCase: Bool? = nil, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedText"] = [ExpectedTextValue(string: expected, ignoreCase: ignoreCase).toParams()]

		try await expect("to.have.title", options: options)
	}

	/// Asserts that the page has the expected URL.
	///
	/// See: https://playwright.dev/docs/api/class-pageassertions#page-assertions-to-have-url
	public func toHaveURL(_ expected: String, ignoreCase: Bool? = nil, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedText"] = [ExpectedTextValue(string: expected, ignoreCase: ignoreCase, normalizeWhiteSpace: false).toParams()]

		try await expect("to.have.url", options: options)
	}

	// MARK: - Internal

	private func baseOptions(timeout: Duration? = nil) -> [String: Any] {
		[
			"isNot": isNot,
			"timeout": resolveTimeout(timeout).milliseconds,
		]
	}

	private func expect(_ expression: String, options: [String: Any]) async throws {
		try checkExpectResult(
			await page.mainFrame._expect(selector: nil, expression: expression, options: options),
			expression: expression,
			selector: nil,
			isNot: isNot,
			message: message,
			sourceLocation: sourceLocation
		)
	}
}
