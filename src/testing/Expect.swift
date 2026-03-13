import Testing
import Playwright

/// Creates a locator assertion builder for verifying element state.
///
/// ```swift
/// try await expect(page.locator("h1")).toBeVisible()
/// try await expect(page.locator("input")).toHaveValue("hello")
/// ```
///
/// - Parameter locator: The locator to assert against.
/// - Parameter message: Optional custom message for assertion failures.
/// - Returns: A `LocatorAssertions` builder for chaining assertions.
public func expect(_ locator: Locator, _ message: String? = nil, sourceLocation: SourceLocation = #_sourceLocation) -> LocatorAssertions {
	LocatorAssertions(isNot: false, message: message, locator: locator, sourceLocation: sourceLocation)
}

/// Creates a page assertion builder for verifying page-level properties.
///
/// ```swift
/// try await expect(page).toHaveTitle("Example Domain")
/// try await expect(page).toHaveURL("https://example.com/")
/// ```
///
/// - Parameter page: The page to assert against.
/// - Parameter message: Optional custom message for assertion failures.
/// - Returns: A `PageAssertions` builder for chaining assertions.
public func expect(_ page: Page, _ message: String? = nil, sourceLocation: SourceLocation = #_sourceLocation) -> PageAssertions {
	PageAssertions(page: page, isNot: false, message: message, sourceLocation: sourceLocation)
}
