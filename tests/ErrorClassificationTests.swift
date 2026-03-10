import Testing
@testable import Playwright

@Suite
struct ErrorClassificationTests {
	@Test("classifies 'waiting for selector' as elementNotFound")
	func waitingForSelector() {
		let msg = "Timeout: waiting for selector 'button' to be visible"
		#expect(PlaywrightError.fromServer(msg) == .elementNotFound(msg))
	}

	@Test("classifies 'waiting for locator' as elementNotFound")
	func waitingForLocator() {
		let msg = "Timeout: waiting for locator('button')"
		#expect(PlaywrightError.fromServer(msg) == .elementNotFound(msg))
	}

	@Test("classifies 'no element matches' as elementNotFound")
	func noElementMatches() {
		let msg = "Error: no element matches selector '.missing'"
		#expect(PlaywrightError.fromServer(msg) == .elementNotFound(msg))
	}

	@Test("classifies 'strict mode violation' as elementNotFound")
	func strictModeViolation() {
		let msg = "Error: strict mode violation: locator resolved to 3 elements"
		#expect(PlaywrightError.fromServer(msg) == .elementNotFound(msg))
	}

	@Test("classifies TypeError as evaluationFailed")
	func typeError() {
		let msg = "TypeError: Cannot read property 'foo' of null"
		#expect(PlaywrightError.fromServer(msg) == .evaluationFailed(msg))
	}

	@Test("classifies ReferenceError as evaluationFailed")
	func referenceError() {
		let msg = "ReferenceError: x is not defined"
		#expect(PlaywrightError.fromServer(msg) == .evaluationFailed(msg))
	}

	@Test("classifies SyntaxError as evaluationFailed")
	func syntaxError() {
		let msg = "SyntaxError: Unexpected token '}'"
		#expect(PlaywrightError.fromServer(msg) == .evaluationFailed(msg))
	}

	@Test("classifies 'evaluation failed' as evaluationFailed")
	func evaluationFailed() {
		let msg = "Evaluation failed: some error"
		#expect(PlaywrightError.fromServer(msg) == .evaluationFailed(msg))
	}

	@Test("classifies 'navigation failed' as navigationFailed")
	func navigationFailed() {
		let msg = "Navigation failed because page was closed"
		#expect(PlaywrightError.fromServer(msg) == .navigationFailed(msg))
	}

	@Test("classifies net::ERR_ as navigationFailed")
	func netError() {
		let msg = "net::ERR_CONNECTION_REFUSED at https://localhost:9999"
		#expect(PlaywrightError.fromServer(msg) == .navigationFailed(msg))
	}

	@Test("classifies TimeoutError name as navigationFailed")
	func timeoutError() {
		let msg = "Timeout 30000ms exceeded."
		#expect(PlaywrightError.fromServer(msg, name: "TimeoutError") == .navigationFailed(msg))
	}

	@Test("classifies unknown error as serverError")
	func unknownError() {
		let msg = "Something unexpected happened"
		#expect(PlaywrightError.fromServer(msg) == .serverError(msg))
	}

	// MARK: - Missing classification patterns

	@Test("classifies 'navigating to' as navigationFailed")
	func navigatingTo() {
		let msg = "Error while navigating to https://bad-url.example"
		#expect(PlaywrightError.fromServer(msg) == .navigationFailed(msg))
	}

	@Test("classifies 'waiting for navigation' as navigationFailed")
	func waitingForNavigation() {
		let msg = "Timeout exceeded while waiting for navigation to complete"
		#expect(PlaywrightError.fromServer(msg) == .navigationFailed(msg))
	}

	@Test("classifies RangeError as evaluationFailed")
	func rangeError() {
		let msg = "RangeError: Maximum call stack size exceeded"
		#expect(PlaywrightError.fromServer(msg) == .evaluationFailed(msg))
	}

	@Test("elementNotFound takes priority over TimeoutError name")
	func elementNotFoundPriority() {
		let msg = "Timeout: waiting for locator('button')"
		#expect(PlaywrightError.fromServer(msg, name: "TimeoutError") == .elementNotFound(msg))
	}

	@Test("case-insensitive classification")
	func caseInsensitive() {
		let msg = "TYPEERROR: something went wrong"
		#expect(PlaywrightError.fromServer(msg) == .evaluationFailed(msg))
	}

	@Test("empty message returns serverError")
	func emptyMessage() {
		#expect(PlaywrightError.fromServer("") == .serverError(""))
	}

	// MARK: - errorDescription

	@Test("invalidArgument errorDescription")
	func invalidArgumentDescription() {
		let error = PlaywrightError.invalidArgument("bad value")
		#expect(error.errorDescription == "bad value")
	}

	@Test("elementNotFound errorDescription")
	func elementNotFoundDescription() {
		let error = PlaywrightError.elementNotFound("waiting for selector 'button'")
		#expect(error.errorDescription == "Element not found: waiting for selector 'button'")
	}

	@Test("navigationFailed errorDescription")
	func navigationFailedDescription() {
		let error = PlaywrightError.navigationFailed("net::ERR_CONNECTION_REFUSED")
		#expect(error.errorDescription == "Navigation failed: net::ERR_CONNECTION_REFUSED")
	}

	@Test("evaluationFailed errorDescription")
	func evaluationFailedDescription() {
		let error = PlaywrightError.evaluationFailed("TypeError: null is not an object")
		#expect(error.errorDescription == "Evaluation failed: TypeError: null is not an object")
	}
}
