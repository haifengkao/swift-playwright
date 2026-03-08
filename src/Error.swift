import Foundation

/// Errors thrown by the Playwright library.
public enum PlaywrightError: Error, LocalizedError {
	/// The Playwright driver binary could not be found.
	case driverNotFound(String)

	/// The Playwright server returned an error response.
	case serverError(String)

	/// The connection to the Playwright server was closed.
	case connectionClosed

	/// The driver process exited immediately after launch.
	case driverExitedEarly(status: Int32, stderr: String?)

	public var errorDescription: String? {
		switch self {
			case .connectionClosed: return "Connection to Playwright server was closed"
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
