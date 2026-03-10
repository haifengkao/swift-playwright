import Foundation

/// ARIA roles for `getByRole()` locators.
///
/// See: https://www.w3.org/TR/wai-aria-1.2/#role_definitions
public enum AriaRole: String, Sendable {
	case alert, alertdialog, application
	case article, banner, blockquote
	case button, caption, cell
	case checkbox, code, columnheader
	case combobox, complementary
	case contentinfo, definition
	case deletion, dialog, directory
	case document, emphasis, feed
	case figure, form, generic
	case grid, gridcell, group
	case heading, img, insertion
	case link, list, listbox
	case listitem, log, main
	case marquee, math, meter
	case menu, menubar, menuitem
	case menuitemcheckbox, menuitemradio
	case navigation, none, note
	case option, paragraph, presentation
	case progressbar, radio, radiogroup
	case region, row, rowgroup
	case rowheader, scrollbar, search
	case searchbox, separator, slider
	case spinbutton, status, strong
	case `subscript`, superscript
	case `switch`, tab, table
	case tablist, tabpanel, term
	case textbox, time, timer
	case toolbar, tooltip, tree
	case treegrid, treeitem
}

/// Options for `getByRole()` locators.
///
/// See: https://playwright.dev/docs/api/class-page#page-get-by-role
public struct GetByRoleOptions: Sendable {
	/// Filter by the accessible name.
	public var name: String?

	/// Whether to match the name exactly.
	public var exact: Bool?

	/// Filter by checked state.
	public var checked: Bool?

	/// Filter by disabled state.
	public var disabled: Bool?

	/// Filter by expanded state.
	public var expanded: Bool?

	/// Include hidden elements.
	public var includeHidden: Bool?

	/// Filter by heading level.
	public var level: Int?

	/// Filter by pressed state.
	public var pressed: Bool?

	/// Filter by selected state.
	public var selected: Bool?

	public init(
		name: String? = nil, exact: Bool? = nil, checked: Bool? = nil,
		disabled: Bool? = nil, expanded: Bool? = nil, includeHidden: Bool? = nil,
		level: Int? = nil, pressed: Bool? = nil, selected: Bool? = nil
	) {
		self.name = name
		self.level = level
		self.exact = exact
		self.checked = checked
		self.pressed = pressed
		self.disabled = disabled
		self.expanded = expanded
		self.selected = selected
		self.includeHidden = includeHidden
	}
}

// MARK: - Selector Builders

enum SelectorBuilder {
	/// Builds a `getByText` selector string.
	static func textSelector(_ text: String, exact: Bool) -> String {
		"internal:text=\(escapeForTextSelector(text, exact: exact))"
	}

	/// Builds a `getByTestId` selector string.
	static func testIdSelector(_ testId: String) -> String {
		"internal:testid=[data-testid=\(escapeForAttributeSelector(testId, exact: true))]"
	}

	/// Builds a `getByLabel` selector string.
	static func labelSelector(_ text: String, exact: Bool) -> String {
		"internal:label=\(escapeForTextSelector(text, exact: exact))"
	}

	/// Builds an attribute-based selector string (used by getByPlaceholder, getByAltText, getByTitle).
	static func attributeSelector(_ attr: String, text: String, exact: Bool) -> String {
		"internal:attr=[\(attr)=\(escapeForAttributeSelector(text, exact: exact))]"
	}

	/// Builds a `getByRole` selector string.
	static func roleSelector(_ role: AriaRole, options: GetByRoleOptions?) -> String {
		var attrs: [String] = []
		if let level = options?.level { attrs.append("level=\(level)") }
		if let pressed = options?.pressed { attrs.append("pressed=\(pressed)") }
		if let checked = options?.checked { attrs.append("checked=\(checked)") }
		if let disabled = options?.disabled { attrs.append("disabled=\(disabled)") }
		if let expanded = options?.expanded { attrs.append("expanded=\(expanded)") }
		if let selected = options?.selected { attrs.append("selected=\(selected)") }
		if let includeHidden = options?.includeHidden { attrs.append("include-hidden=\(includeHidden)") }
		if let name = options?.name { attrs.append("name=\(escapeForAttributeSelector(name, exact: options?.exact ?? false))") }

		return "internal:role=\(role.rawValue)\(attrs.isEmpty ? "" : "[\(attrs.joined(separator: "]["))]")"
	}

	// MARK: - Escaping

	/// Escapes a string for text selectors using JSON serialization.
	///
	/// Used by `getByText`, `getByLabel`, and `filter(hasText:)` / `filter(hasNotText:)`.
	/// Matches playwright-python's `escape_for_text_selector` (`json.dumps`).
	static func escapeForTextSelector(_ text: String, exact: Bool) -> String {
		"\(jsonQuote(text))\(exact ? "s" : "i")"
	}

	/// Escapes a string for attribute selectors using manual escaping.
	///
	/// Used by `getByTestId`, `getByPlaceholder`, `getByAltText`, `getByTitle`,
	/// and `getByRole` name parameter. Only escapes `\` and `"`.
	/// Matches playwright-python's `escape_for_attribute_selector`.
	static func escapeForAttributeSelector(_ text: String, exact: Bool) -> String {
		"\(manualQuote(text))\(exact ? "s" : "i")"
	}

	/// JSON-serializes a string, producing a quoted and escaped JSON string literal.
	///
	/// Handles control characters (`\n`, `\t`, etc.), Unicode, backslashes, and quotes.
	/// Used for text selectors and structural combinators (`has`, `or`, `and`, `chain`).
	static func jsonQuote(_ text: String) -> String {
		// JSONSerialization handles all escaping; fragmentsAllowed permits a bare string.
		// A valid String can never fail to serialize, so try! is safe.
		let data = try! JSONSerialization.data(withJSONObject: text, options: .fragmentsAllowed)
		return String(data: data, encoding: .utf8)!
	}

	/// Manual quote escaping for attribute selectors — only escapes `\` and `"`.
	private static func manualQuote(_ text: String) -> String {
		guard text.contains("\\") || text.contains("\"") else { return "\"\(text)\"" }

		let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
		return "\"\(escaped)\""
	}
}
