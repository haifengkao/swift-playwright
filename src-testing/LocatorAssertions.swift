import Testing
import Playwright

/// Builder for asserting on locator state, text, attributes, and more.
///
/// Created via `expect(locator)`. All assertions are server-side with auto-retry.
///
/// ```swift
/// try await expect(page.locator("h1")).toBeVisible()
/// try await expect(page.locator("input")).not.toBeEmpty()
/// try await expect(page.locator("li")).toHaveCount(3)
/// ```
public struct LocatorAssertions: Sendable {
	let isNot: Bool
	let message: String?
	let locator: Locator
	let sourceLocation: SourceLocation

	/// Returns a negated assertion builder.
	///
	/// ```swift
	/// try await expect(locator).not.toBeVisible()
	/// ```
	public var not: LocatorAssertions {
		LocatorAssertions(isNot: !isNot, message: message, locator: locator, sourceLocation: sourceLocation)
	}

	// MARK: - State Assertions

	/// Asserts that the element is visible.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-visible
	public func toBeVisible(timeout: Duration? = nil) async throws {
		try await expectState("to.be.visible", timeout: timeout)
	}

	/// Asserts that the element is hidden.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-hidden
	public func toBeHidden(timeout: Duration? = nil) async throws {
		try await expectState("to.be.hidden", timeout: timeout)
	}

	/// Asserts that the element is enabled.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-enabled
	public func toBeEnabled(timeout: Duration? = nil) async throws {
		try await expectState("to.be.enabled", timeout: timeout)
	}

	/// Asserts that the element is disabled.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-disabled
	public func toBeDisabled(timeout: Duration? = nil) async throws {
		try await expectState("to.be.disabled", timeout: timeout)
	}

	/// Asserts that the element is editable.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-editable
	public func toBeEditable(timeout: Duration? = nil) async throws {
		try await expectState("to.be.editable", timeout: timeout)
	}

	/// Asserts that the element is checked.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-checked
	public func toBeChecked(timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedValue"] = try EvaluateSerializer.serializeArgument(["checked": true])

		try await expect("to.be.checked", options: options)
	}

	/// Asserts that the element is focused.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-focused
	public func toBeFocused(timeout: Duration? = nil) async throws {
		try await expectState("to.be.focused", timeout: timeout)
	}

	/// Asserts that the element is empty (no text content for inputs, no children for others).
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-empty
	public func toBeEmpty(timeout: Duration? = nil) async throws {
		try await expectState("to.be.empty", timeout: timeout)
	}

	/// Asserts that the element is attached to the DOM.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-attached
	public func toBeAttached(timeout: Duration? = nil) async throws {
		try await expectState("to.be.attached", timeout: timeout)
	}

	/// Asserts that the element is in the viewport.
	///
	/// - Param ratio: The minimal ratio of the element to intersect viewport.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-be-in-viewport
	public func toBeInViewport(ratio: Double? = nil, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		if let ratio { options["expectedNumber"] = ratio }

		try await expect("to.be.in.viewport", options: options)
	}

	// MARK: - Text Assertions

	/// Asserts that the element has the expected text content.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-text
	public func toHaveText(_ expected: String, ignoreCase: Bool? = nil, useInnerText: Bool? = nil, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		if let useInnerText { options["useInnerText"] = useInnerText }
		options["expectedText"] = [ExpectedTextValue(string: expected, ignoreCase: ignoreCase).toParams()]

		try await expect("to.have.text", options: options)
	}

	/// Asserts that the element contains the expected text as a substring.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-contain-text
	public func toContainText(_ expected: String, ignoreCase: Bool? = nil, useInnerText: Bool? = nil, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		if let useInnerText { options["useInnerText"] = useInnerText }
		options["expectedText"] = [ExpectedTextValue(string: expected, ignoreCase: ignoreCase, matchSubstring: true).toParams()]

		try await expect("to.have.text", options: options)
	}

	// MARK: - Attribute Assertions

	/// Asserts that the element has the specified attribute with the expected value.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-attribute
	public func toHaveAttribute(_ name: String, _ value: String, ignoreCase: Bool? = nil, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expressionArg"] = name
		options["expectedText"] = [ExpectedTextValue(string: value, ignoreCase: ignoreCase, normalizeWhiteSpace: false).toParams()]

		try await expect("to.have.attribute.value", options: options)
	}

	/// Asserts that the input element has the expected value.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-value
	public func toHaveValue(_ value: String, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedText"] = [ExpectedTextValue(string: value, normalizeWhiteSpace: false).toParams()]

		try await expect("to.have.value", options: options)
	}

	/// Asserts that the element has the expected CSS class.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-class
	public func toHaveClass(_ expected: String, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedText"] = [ExpectedTextValue(string: expected).toParams()]

		try await expect("to.have.class", options: options)
	}

	/// Asserts that the element has the expected computed CSS property value.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-css
	public func toHaveCSS(_ name: String, _ value: String, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expressionArg"] = name
		options["expectedText"] = [ExpectedTextValue(string: value, normalizeWhiteSpace: false).toParams()]

		try await expect("to.have.css", options: options)
	}

	/// Asserts that the element has the expected ID.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-id
	public func toHaveId(_ id: String, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedText"] = [ExpectedTextValue(string: id, normalizeWhiteSpace: false).toParams()]

		try await expect("to.have.id", options: options)
	}

	// MARK: - Count Assertion

	/// Asserts that the locator matches the expected number of elements.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-count
	public func toHaveCount(_ count: Int, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedNumber"] = count

		try await expect("to.have.count", options: options)
	}

	// MARK: - Accessibility Assertions

	/// Asserts that the element has the expected accessible name.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-accessible-name
	public func toHaveAccessibleName(_ name: String, ignoreCase: Bool? = nil, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedText"] = [ExpectedTextValue(string: name, ignoreCase: ignoreCase).toParams()]

		try await expect("to.have.accessible.name", options: options)
	}

	/// Asserts that the element has the expected accessible description.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-accessible-description
	public func toHaveAccessibleDescription(_ description: String, ignoreCase: Bool? = nil, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedText"] = [ExpectedTextValue(string: description, ignoreCase: ignoreCase).toParams()]

		try await expect("to.have.accessible.description", options: options)
	}

	/// Asserts that the element has the expected ARIA role.
	///
	/// See: https://playwright.dev/docs/api/class-locatorassertions#locator-assertions-to-have-role
	public func toHaveRole(_ role: AriaRole, timeout: Duration? = nil) async throws {
		var options = baseOptions(timeout: timeout)
		options["expectedText"] = [ExpectedTextValue(string: role.rawValue, normalizeWhiteSpace: false).toParams()]

		try await expect("to.have.role", options: options)
	}

	// MARK: - Internal

	private func expectState(_ expression: String, timeout: Duration? = nil) async throws {
		try await expect(expression, options: baseOptions(timeout: timeout))
	}

	private func baseOptions(timeout: Duration? = nil) -> [String: Any] {
		[
			"isNot": isNot,
			"timeout": resolveTimeout(timeout).milliseconds,
		]
	}

	private func expect(_ expression: String, options: [String: Any]) async throws {
		try checkExpectResult(
			await locator.frame._expect(selector: locator.selector, expression: expression, options: options),
			expression: expression,
			selector: locator.selector,
			isNot: isNot,
			message: message,
			sourceLocation: sourceLocation
		)
	}
}
