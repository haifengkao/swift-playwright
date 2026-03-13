import Foundation

/// Errors thrown by the Playwright library.
public enum PlaywrightError: Error, LocalizedError, Equatable {
	/// The Playwright driver binary could not be found.
	case driverNotFound(String)

	/// The Playwright server returned an error response.
	case serverError(String)

	/// The connection to the Playwright server was closed.
	case connectionClosed

	/// The driver process exited immediately after launch.
	case driverExitedEarly(status: Int32, stderr: String?)

	/// An invalid argument was passed to a Playwright API.
	case invalidArgument(String)

	/// A page navigation failed, timed out, or was aborted.
	case navigationFailed(String)

	/// A selector did not match any element within the timeout.
	case elementNotFound(String)

	/// JavaScript evaluation inside the browser context failed.
	case evaluationFailed(String)

	/// Parses a raw server error into the most specific error case.
	///
	/// - Parameter message: The error message, with call log appended when available.
	/// - Parameter name: The server error class name (e.g. "TimeoutError", "Error").
	static func fromServer(_ message: String, name: String? = nil) -> PlaywrightError {
		let lower = message.lowercased()

		// check element/selector patterns first: covers both the message and the appended call log (e.g. `waiting for locator(\"button\")`).
		if lower.contains("waiting for selector") || lower.contains("waiting for locator") || lower.contains("no element matches") || lower.contains("strict mode violation") {
			return .elementNotFound(message)
		}
		if lower.contains("evaluation failed") || lower.contains("typeerror") || lower.contains("referenceerror") || lower.contains("syntaxerror") || lower.contains("rangeerror") {
			return .evaluationFailed(message)
		}
		if lower.contains("navigation failed") || lower.contains("net::err_") || lower.contains("navigating to") || lower.contains("waiting for navigation") {
			return .navigationFailed(message)
		}

		// Use the server's error name as a fallback — a TimeoutError that didn't
		// match any specific pattern above is most likely a navigation timeout.
		if name == "TimeoutError" { return .navigationFailed(message) }

		return .serverError(message)
	}

	public var errorDescription: String? {
		switch self {
			case let .invalidArgument(message): return message
			case let .elementNotFound(message): return "Element not found: \(message)"
			case .connectionClosed: return "Connection to Playwright server was closed"
			case let .navigationFailed(message): return "Navigation failed: \(message)"
			case let .evaluationFailed(message): return "Evaluation failed: \(message)"
			case let .serverError(message): return "Playwright server error: \(message)"
			case let .driverNotFound(message): return "Playwright driver not found: \(message)"
			case let .driverExitedEarly(status, stderr):
				var msg = "Playwright driver exited immediately after launch (status \(status))"
				if let stderr, !stderr.isEmpty {
					msg += ": \(stderr)"
				}
				return msg
		}
	}
}
