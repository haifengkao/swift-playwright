import Testing
import Foundation
@testable import PlaywrightTesting

/// Pure unit tests for assertion failure message building — no browser needed.
@Suite
struct AssertionResultTests {
	// MARK: - Passing assertions

	@Test("returns nil when assertion passes (matches=true, isNot=false)")
	func passingAssertion() {
		let result: [String: Any] = ["matches": NSNumber(value: true)]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "h1", isNot: false, message: nil)
		#expect(message == nil)
	}

	@Test("returns nil when negated assertion passes (matches=false, isNot=true)")
	func passingNegatedAssertion() {
		let result: [String: Any] = ["matches": NSNumber(value: false)]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "h1", isNot: true, message: nil)
		#expect(message == nil)
	}

	// MARK: - Generic failure message

	@Test("builds generic message for locator assertion failure")
	func genericLocatorFailure() {
		let result: [String: Any] = ["matches": NSNumber(value: false)]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "h1", isNot: false, message: nil)
		#expect(message == "Expected locator(\"h1\") to be visible")
	}

	@Test("builds generic message for page assertion failure")
	func genericPageFailure() {
		let result: [String: Any] = ["matches": NSNumber(value: false)]
		let message = buildExpectFailureMessage(result, expression: "to.have.title", selector: nil, isNot: false, message: nil)
		#expect(message == "Expected page to have title")
	}

	@Test("includes 'not' prefix for negated assertion failure")
	func negatedFailure() {
		let result: [String: Any] = ["matches": NSNumber(value: true)]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "h1", isNot: true, message: nil)
		#expect(message == "Expected locator(\"h1\") not to be visible")
	}

	// MARK: - Protocol error messages

	@Test("surfaces 'error' field from server response instead of generic message")
	func errorFieldSurfaced() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"error": "Selector engine \"bad\" is not recognized",
		]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "bad >> div", isNot: false, message: nil)
		#expect(message?.contains("Selector engine \"bad\" is not recognized") == true)
		#expect(message?.contains("Expected locator") != true)
	}

	@Test("surfaces 'message' field when 'error' is absent")
	func messageFieldSurfaced() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"message": "Element is not stable - waiting for fonts",
		]
		let message = buildExpectFailureMessage(result, expression: "to.be.checked", selector: "input", isNot: false, message: nil)
		#expect(message?.contains("Element is not stable") == true)
		#expect(message?.contains("Expected locator") != true)
	}

	@Test("surfaces 'errorMessage' field (locator not found, strict-mode violations)")
	func errorMessageFieldSurfaced() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"errorMessage": "Error: strict mode violation: locator resolved to 3 elements",
		]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "div", isNot: false, message: nil)
		#expect(message?.contains("strict mode violation") == true)
		#expect(message?.contains("Expected locator") != true)
	}

	@Test("prefers 'error' over 'errorMessage' over 'message'")
	func errorFieldPriority() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"error": "The specific error",
			"errorMessage": "An assertion error message",
			"message": "A generic message",
		]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "div", isNot: false, message: nil)
		#expect(message?.contains("The specific error") == true)
		#expect(message?.contains("assertion error message") != true)
		#expect(message?.contains("A generic message") != true)
	}

	@Test("falls back from 'errorMessage' to 'message' when only 'message' present")
	func fallbackToMessage() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"message": "A generic message",
		]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "div", isNot: false, message: nil)
		#expect(message?.contains("A generic message") == true)
	}

	// MARK: - Custom user message

	@Test("prepends custom user message")
	func customMessagePrepended() {
		let result: [String: Any] = ["matches": NSNumber(value: false)]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "h1", isNot: false, message: "Login button should appear")
		#expect(message?.hasPrefix("Login button should appear") == true)
		#expect(message?.contains("Expected locator(\"h1\") to be visible") == true)
	}

	@Test("prepends custom message alongside protocol error")
	func customMessageWithError() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"error": "Selector syntax error",
		]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: ">>bad", isNot: false, message: "Check failed")
		#expect(message?.hasPrefix("Check failed") == true)
		#expect(message?.contains("Selector syntax error") == true)
	}

	// MARK: - Received parsing

	@Test("parses received tagged string value {s: ...}")
	func receivedTaggedString() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"received": ["s": "Actual Title"],
		]
		let message = buildExpectFailureMessage(result, expression: "to.have.title", selector: nil, isNot: false, message: nil)
		#expect(message?.contains("Received: Actual Title") == true)
	}

	@Test("parses received tagged number value {n: ...}")
	func receivedTaggedNumber() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"received": ["n": 5],
		]
		let message = buildExpectFailureMessage(result, expression: "to.have.count", selector: "li", isNot: false, message: nil)
		#expect(message?.contains("Received: 5") == true)
	}

	@Test("parses received tagged boolean value {b: ...}")
	func receivedTaggedBool() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"received": ["b": true],
		]
		let message = buildExpectFailureMessage(result, expression: "to.be.checked", selector: "input", isNot: false, message: nil)
		#expect(message?.contains("Received: true") == true)
	}

	@Test("renders tagged null received as 'null' instead of raw payload")
	func receivedTaggedNull() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"received": ["v": "null"],
		]
		let message = buildExpectFailureMessage(result, expression: "to.have.attribute.value", selector: "a", isNot: false, message: nil)
		#expect(message?.contains("Received: null") == true)
		#expect(message?.contains("{") != true)
	}

	@Test("renders tagged undefined received as 'null' instead of raw payload")
	func receivedTaggedUndefined() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"received": ["v": "undefined"],
		]
		let message = buildExpectFailureMessage(result, expression: "to.have.value", selector: "input", isNot: false, message: nil)
		#expect(message?.contains("Received: null") == true)
		#expect(message?.contains("{") != true)
	}

	@Test("passes through non-tagged received value as-is")
	func receivedPlainValue() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"received": "plain string",
		]
		let message = buildExpectFailureMessage(result, expression: "to.have.title", selector: nil, isNot: false, message: nil)
		#expect(message?.contains("Received: plain string") == true)
	}

	// MARK: - Log

	@Test("includes log lines in failure message")
	func logIncluded() {
		let result: [String: Any] = [
			"matches": NSNumber(value: false),
			"log": ["waiting for locator(\"h1\")", "  locator resolved to 0 elements"],
		]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "h1", isNot: false, message: nil)
		#expect(message?.contains("Log: waiting for locator(\"h1\")") == true)
		#expect(message?.contains("locator resolved to 0 elements") == true)
	}

	// MARK: - Edge cases

	@Test("treats missing 'matches' as false (assertion fails)")
	func missingMatchesTreatedAsFalse() {
		let result: [String: Any] = [:]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "h1", isNot: false, message: nil)
		#expect(message != nil)
	}

	@Test("treats missing 'matches' with isNot=true as passing")
	func missingMatchesWithIsNotPasses() {
		let result: [String: Any] = [:]
		let message = buildExpectFailureMessage(result, expression: "to.be.visible", selector: "h1", isNot: true, message: nil)
		#expect(message == nil)
	}
}
