/// Represents expected text for Playwright assertions.
///
/// Serialized to the server's `expectedText` format for text-based assertions.
struct ExpectedTextValue: Sendable {
	var string: String?
	var ignoreCase: Bool?
	var matchSubstring = false
	var normalizeWhiteSpace = true

	/// Converts to the dictionary format expected by the Playwright protocol.
	func toParams() -> [String: Any] {
		var dict: [String: Any] = [
			"matchSubstring": matchSubstring,
			"normalizeWhiteSpace": normalizeWhiteSpace,
		]

		if let string { dict["string"] = string }
		if let ignoreCase { dict["ignoreCase"] = ignoreCase }

		return dict
	}
}
