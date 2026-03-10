import Testing
import Foundation
@testable import Playwright

/// Pure unit tests for helper functions — no browser needed.
@Suite
struct HelpersTests {
	// MARK: - parseHeaders

	@Test("parseHeaders merges duplicate standard headers with comma")
	func parseHeadersDuplicateStandard() {
		let raw: [[String: Any]] = [
			["name": "Cache-Control", "value": "no-cache"],
			["name": "Cache-Control", "value": "no-store"],
		]
		let result = parseHeaders(raw)
		#expect(result["cache-control"] == "no-cache, no-store")
	}

	@Test("parseHeaders merges duplicate set-cookie with newline")
	func parseHeadersDuplicateSetCookie() {
		let raw: [[String: Any]] = [
			["name": "Set-Cookie", "value": "a=1"],
			["name": "Set-Cookie", "value": "b=2"],
		]
		let result = parseHeaders(raw)
		#expect(result["set-cookie"] == "a=1\nb=2")
	}

	@Test("parseHeaders returns empty dict for nil")
	func parseHeadersNil() {
		#expect(parseHeaders(nil) == [:])
	}

	@Test("parseHeaders returns empty dict for empty array")
	func parseHeadersEmpty() {
		#expect(parseHeaders([] as [[String: Any]]) == [:])
	}

	@Test("parseHeaders skips entries with missing name or value")
	func parseHeadersMalformed() {
		let raw: [[String: Any]] = [
			["name": "Good", "value": "header"],
			["name": "Missing-Value"],
			["value": "Missing-Name"],
			[:],
		]
		let result = parseHeaders(raw)
		#expect(result.count == 1)
		#expect(result["good"] == "header")
	}

	// MARK: - decodeBase64Binary

	@Test("decodeBase64Binary throws serverError on missing key")
	func decodeBase64MissingKey() {
		#expect {
			_ = try decodeBase64Binary([:])
		} throws: { error in
			guard case PlaywrightError.serverError = error else { return false }
			return true
		}
	}

	@Test("decodeBase64Binary throws serverError on invalid base64")
	func decodeBase64Invalid() {
		#expect {
			_ = try decodeBase64Binary(["binary": "not-valid-base64!!!"])
		} throws: { error in
			guard case PlaywrightError.serverError = error else { return false }
			return true
		}
	}

	@Test("decodeBase64Binary succeeds with valid data")
	func decodeBase64Valid() throws {
		let original = Data("hello".utf8)
		let b64 = original.base64EncodedString()
		let result = try decodeBase64Binary(["binary": b64])
		#expect(result == original)
	}

	// MARK: - screenshotParams

	@Test("screenshotParams omits quality for PNG")
	func screenshotParamsPNGNoQuality() throws {
		let params = try screenshotParams(type: .png)
		#expect(params["quality"] == nil)
	}

	@Test("screenshotParams includes quality for JPEG")
	func screenshotParamsJPEGQuality() throws {
		let params = try screenshotParams(type: .jpeg, quality: 80)
		#expect(params["quality"] as? Int == 80)
	}

	@Test("screenshotParams includes omitBackground")
	func screenshotParamsOmitBackground() throws {
		let params = try screenshotParams(omitBackground: true)
		#expect(params["omitBackground"] as? Bool == true)
	}

	@Test("screenshotParams omits omitBackground when nil")
	func screenshotParamsOmitBackgroundNil() throws {
		let params = try screenshotParams()
		#expect(params["omitBackground"] == nil)
	}

	@Test("screenshotParams with explicit type and unsupported path does not throw")
	func screenshotParamsExplicitTypeWithBadPath() throws {
		let params = try screenshotParams(type: .jpeg, path: "shot.gif")
		#expect(params["type"] as? String == "jpeg")
	}
}
