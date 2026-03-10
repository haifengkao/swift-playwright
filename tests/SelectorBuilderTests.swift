import Testing
@testable import Playwright

/// Pure unit tests for SelectorBuilder — no browser needed.
@Suite
struct SelectorBuilderTests {
	@Test("roleSelector builds correct selector")
	func roleSelector() {
		#expect(SelectorBuilder.roleSelector(.button, options: nil) == "internal:role=button")
		#expect(SelectorBuilder.roleSelector(.button, options: .init(name: "Submit")) == #"internal:role=button[name="Submit"i]"#)
	}

	@Test("textSelector builds correct selector")
	func textSelector() {
		#expect(SelectorBuilder.textSelector("Hello", exact: false) == #"internal:text="Hello"i"#)
	}

	@Test("testIdSelector builds correct selector")
	func idSelector() {
		#expect(SelectorBuilder.testIdSelector("submit-btn") == #"internal:testid=[data-testid="submit-btn"s]"#)
	}

	@Test("labelSelector builds correct selector")
	func labelSelector() {
		#expect(SelectorBuilder.labelSelector("Email", exact: false) == #"internal:label="Email"i"#)
	}

	@Test("attributeSelector builds correct selector for placeholder, alt, title")
	func attributeSelector() {
		#expect(SelectorBuilder.attributeSelector("placeholder", text: "Enter name", exact: false) == #"internal:attr=[placeholder="Enter name"i]"#)
		#expect(SelectorBuilder.attributeSelector("alt", text: "Logo", exact: true) == #"internal:attr=[alt="Logo"s]"#)
		#expect(SelectorBuilder.attributeSelector("title", text: "Close", exact: false) == #"internal:attr=[title="Close"i]"#)
	}

	@Test("escapeForTextSelector escapes control characters")
	func escapesControlChars() {
		let escaped = SelectorBuilder.escapeForTextSelector("Line 1\nLine 2", exact: false)
		#expect(escaped.contains("\\n"))
		#expect(!escaped.contains("\n"))
	}

	@Test("escapeForTextSelector appends 's' for exact, 'i' for inexact")
	func exactFlag() {
		let exact = SelectorBuilder.escapeForTextSelector("Hello", exact: true)
		#expect(exact.hasSuffix("s"))

		let inexact = SelectorBuilder.escapeForTextSelector("Hello", exact: false)
		#expect(inexact.hasSuffix("i"))
	}

	@Test("roleSelector includes all filter options")
	func roleSelectorOptions() {
		#expect(SelectorBuilder.roleSelector(.checkbox, options: .init(
			checked: true, disabled: false, level: 2
		)) == "internal:role=checkbox[level=2][checked=true][disabled=false]")
	}

	// MARK: - Additional role options

	@Test("roleSelector includes expanded, selected, pressed, includeHidden")
	func roleSelectorAllOptions() {
		#expect(SelectorBuilder.roleSelector(.button, options: .init(
			expanded: true, includeHidden: true, pressed: false, selected: true
		)) == "internal:role=button[pressed=false][expanded=true][selected=true][include-hidden=true]")
	}

	// MARK: - Escaping edge cases

	@Test("escapeForAttributeSelector handles backslash and quote")
	func attributeSelectorEscapesSpecialChars() {
		let withQuote = SelectorBuilder.escapeForAttributeSelector(#"say "hello""#, exact: true)
		#expect(withQuote.contains(#"\""#))

		let withBackslash = SelectorBuilder.escapeForAttributeSelector(#"path\to\file"#, exact: true)
		#expect(withBackslash.contains(#"\\"#))
	}

	@Test("escapeForTextSelector handles tab character")
	func textSelectorEscapesTab() {
		let escaped = SelectorBuilder.escapeForTextSelector("col1\tcol2", exact: false)
		#expect(escaped.contains("\\t"))
		#expect(!escaped.contains("\t"))
	}

	@Test("textSelector with exact: true uses 's' suffix")
	func textSelectorExact() {
		let selector = SelectorBuilder.textSelector("Hello", exact: true)
		#expect(selector.hasSuffix("s"))
	}

	@Test("escapeForAttributeSelector inexact uses 'i' suffix")
	func attributeSelectorInexact() {
		let selector = SelectorBuilder.escapeForAttributeSelector("test", exact: false)
		#expect(selector.hasSuffix("i"))
	}
}
