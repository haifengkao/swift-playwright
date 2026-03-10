import Foundation

/// When to consider a navigation as finished.
///
/// See: https://playwright.dev/docs/api/class-page#page-goto-option-wait-until
public enum WaitUntilState: String, Sendable {
	/// Wait for the `load` event.
	case load

	/// Wait for the `DOMContentLoaded` event.
	case domcontentloaded

	/// Wait until there are no more than 0 network connections for at least 500ms.
	case networkidle

	/// Wait for the first network response.
	case commit
}
