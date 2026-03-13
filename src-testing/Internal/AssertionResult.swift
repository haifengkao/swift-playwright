import Testing
import Foundation
import Playwright

/// Checks the result of a Frame._expect call and records an Issue if the assertion failed.
///
/// - Parameter result: The server response dictionary.
/// - Parameter expression: The assertion expression (for error message).
/// - Parameter selector: The selector used (for error message), or nil for page assertions.
/// - Parameter isNot: Whether this is a negated assertion.
/// - Parameter message: Optional custom message from the user.
/// - Parameter sourceLocation: The source location of the expect() call.
func checkExpectResult(
	_ result: [String: Any],
	expression: String,
	selector: String?,
	isNot: Bool,
	message: String?,
	sourceLocation: SourceLocation
) {
	guard let failureMessage = buildExpectFailureMessage(result, expression: expression, selector: selector, isNot: isNot, message: message) else { return }

	Issue.record(Comment(rawValue: failureMessage), sourceLocation: sourceLocation)
}

/// Builds the failure message for a failed expect result, or returns `nil` if the assertion passed.
///
/// Separated from `checkExpectResult` so the message-building logic can be unit-tested
/// without triggering `Issue.record`.
func buildExpectFailureMessage(
	_ result: [String: Any],
	expression: String,
	selector: String?,
	isNot: Bool,
	message: String?
) -> String? {
	let matchesValue = result["matches"]

	let matches = if let n = matchesValue as? NSNumber { n.boolValue }
	else { false }

	// Server returns `matches` indicating whether the POSITIVE condition was met.
	// With `isNot`, the assertion fails when matches == isNot:
	//   - isNot=false: fails when matches=false (condition not met)
	//   - isNot=true: fails when matches=true (condition met, but we wanted NOT)
	if matches != isNot { return nil }

	let received = result["received"]
	let log = result["log"] as? [String]
	let errorMessage = (result["error"] as? String) ?? (result["errorMessage"] as? String) ?? (result["message"] as? String)

	var parts: [String] = []
	if let message { parts.append(message) }

	if let errorMessage { parts.append(errorMessage) }
	else {
		let target = selector.map { "locator(\"\($0)\")" } ?? "page"
		let prefix = isNot ? "not " : ""
		let readableExpression = expression.replacingOccurrences(of: ".", with: " ")
		parts.append("Expected \(target) \(prefix)\(readableExpression)")
	}

	if let received {
		if received is [String: Any] {
			parts.append("Received: \(EvaluateSerializer.parseResult(received) ?? "null")")
		} else {
			parts.append("Received: \(received)")
		}
	}

	if let log, !log.isEmpty {
		parts.append("Log: \(log.joined(separator: "\n     "))")
	}

	return parts.joined(separator: "\n")
}
