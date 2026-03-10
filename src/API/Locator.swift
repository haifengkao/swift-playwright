import Foundation

/// A client-side locator that identifies elements on the page.
///
/// Locators are the recommended way to find elements in Playwright. They are
/// created via `page.locator()` or `page.getByRole()` etc. and support chaining,
/// filtering, and composition.
///
/// Locators are purely client-side objects — no server communication happens
/// until you call an action or query method on them.
///
/// ```swift
/// let button = page.locator("button.submit")
/// try await button.click()
///
/// let input = page.getByLabel("Email")
/// try await input.fill("user@example.com")
/// ```
///
/// See: https://playwright.dev/docs/api/class-locator
public struct Locator: LocatorFactory, Sendable {
	let frame: Frame
	let selector: String

	init(_ frame: Frame, selector: String) {
		self.frame = frame
		self.selector = selector
	}

	// MARK: - Chaining

	/// Creates a locator that matches a child/descendant of this locator.
	///
	/// - Parameter selector: The CSS or Playwright selector.
	/// - Returns: A new locator with the combined selector.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-locator
	public func locator(_ selector: String) -> Locator {
		Locator(frame, selector: "\(self.selector) >> \(selector)")
	}

	/// Creates a locator that matches a child/descendant matching another locator.
	///
	/// - Parameter locator: The child locator.
	/// - Returns: A new locator with the combined selector.
	/// - Throws: `PlaywrightError.invalidArgument` if the locators belong to different frames.
	public func locator(_ locator: Locator) throws -> Locator {
		try ensureSameFrame(locator)
		return Locator(frame, selector: "\(selector) >> internal:chain=\(SelectorBuilder.jsonQuote(locator.selector))")
	}

	/// Returns a locator for the first matching element.
	public var first: Locator {
		Locator(frame, selector: "\(selector) >> nth=0")
	}

	/// Returns a locator for the last matching element.
	public var last: Locator {
		Locator(frame, selector: "\(selector) >> nth=-1")
	}

	/// Returns a locator for the nth matching element (0-based).
	///
	/// - Parameter index: The zero-based index. Negative values count from the end.
	public func nth(_ index: Int) -> Locator {
		Locator(frame, selector: "\(selector) >> nth=\(index)")
	}

	// MARK: - Filtering

	/// Filters this locator to elements containing the given text.
	///
	/// - Parameter hasText: The text to match.
	/// - Returns: A new filtered locator.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-filter
	public func filter(hasText: String) -> Locator {
		appending(engine: "has-text", value: SelectorBuilder.escapeForTextSelector(hasText, exact: false))
	}

	/// Filters this locator to elements NOT containing the given text.
	///
	/// - Parameter notHasText: The text that must not be present.
	/// - Returns: A new filtered locator.
	public func filter(notHasText: String) -> Locator {
		appending(engine: "has-not-text", value: SelectorBuilder.escapeForTextSelector(notHasText, exact: false))
	}

	/// Filters this locator to elements containing a descendant matching the given locator.
	///
	/// - Parameter has: The child locator that must match.
	/// - Returns: A new filtered locator.
	/// - Throws: `PlaywrightError.invalidArgument` if the locators belong to different frames.
	public func filter(has: Locator) throws -> Locator {
		try composing(engine: "has", with: has)
	}

	/// Filters this locator to elements NOT containing a descendant matching the given locator.
	///
	/// - Parameter hasNot: The child locator that must not match.
	/// - Returns: A new filtered locator.
	/// - Throws: `PlaywrightError.invalidArgument` if the locators belong to different frames.
	public func filter(hasNot: Locator) throws -> Locator {
		try composing(engine: "has-not", with: hasNot)
	}

	// MARK: - Composition

	/// Creates a locator matching elements that match either this or the other locator.
	///
	/// - Parameter locator: The alternative locator.
	/// - Returns: A composed locator.
	/// - Throws: `PlaywrightError.invalidArgument` if the locators belong to different frames.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-or
	public func or(_ locator: Locator) throws -> Locator {
		try composing(engine: "or", with: locator)
	}

	/// Creates a locator matching elements that match both this and the other locator.
	///
	/// - Parameter locator: The additional constraint.
	/// - Returns: A composed locator.
	/// - Throws: `PlaywrightError.invalidArgument` if the locators belong to different frames.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-and
	public func and(_ locator: Locator) throws -> Locator {
		try composing(engine: "and", with: locator)
	}

	/// Appends a selector engine with a value to create a new locator.
	private func appending(engine: String, value: String) -> Locator {
		Locator(frame, selector: "\(selector) >> internal:\(engine)=\(value)")
	}

	/// Composes with another locator using the given engine, verifying same-frame.
	private func composing(engine: String, with other: Locator) throws -> Locator {
		try ensureSameFrame(other)
		return appending(engine: engine, value: SelectorBuilder.jsonQuote(other.selector))
	}

	/// Validates that the other locator belongs to the same frame.
	private func ensureSameFrame(_ other: Locator) throws {
		guard other.frame === frame else {
			throw PlaywrightError.invalidArgument("Locators must belong to the same frame.")
		}
	}

	// MARK: - Actions

	/// Clicks the element.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-click
	public func click(
		button: MouseButton? = nil, clickCount: Int? = nil, delay: Duration? = nil,
		force: Bool? = nil, modifiers: [KeyboardModifier]? = nil, position: Position? = nil,
		timeout: Duration? = nil, trial: Bool? = nil
	) async throws {
		try await frame.click(selector, button: button, clickCount: clickCount, delay: delay, force: force, modifiers: modifiers, position: position, timeout: timeout, trial: trial)
	}

	/// Double-clicks the element.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-dblclick
	public func dblclick(
		button: MouseButton? = nil, delay: Duration? = nil,
		force: Bool? = nil, modifiers: [KeyboardModifier]? = nil, position: Position? = nil,
		timeout: Duration? = nil, trial: Bool? = nil
	) async throws {
		try await frame.dblclick(selector, button: button, delay: delay, force: force, modifiers: modifiers, position: position, timeout: timeout, trial: trial)
	}

	/// Fills an input field with the given value.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-fill
	public func fill(_ value: String, force: Bool? = nil, timeout: Duration? = nil) async throws {
		try await frame.fill(selector, value: value, force: force, timeout: timeout)
	}

	/// Clears an input field.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-clear
	public func clear(timeout: Duration? = nil) async throws {
		try await frame.fill(selector, value: "", timeout: timeout)
	}

	/// Presses a key or key combination.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-press
	public func press(_ key: String, timeout: Duration? = nil) async throws {
		try await frame.press(selector, key: key, timeout: timeout)
	}

	/// Types text character by character with a delay between each keystroke.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-press-sequentially
	public func pressSequentially(_ text: String, timeout: Duration? = nil) async throws {
		try await frame.pressSequentially(selector, text: text, timeout: timeout)
	}

	/// Checks a checkbox or radio button.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-check
	public func check(timeout: Duration? = nil) async throws {
		try await frame.check(selector, timeout: timeout)
	}

	/// Unchecks a checkbox.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-uncheck
	public func uncheck(timeout: Duration? = nil) async throws {
		try await frame.uncheck(selector, timeout: timeout)
	}

	/// Sets the checked state of a checkbox.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-set-checked
	public func setChecked(_ checked: Bool, timeout: Duration? = nil) async throws {
		try await frame.setChecked(selector, checked: checked, timeout: timeout)
	}

	/// Hovers over the element.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-hover
	public func hover(timeout: Duration? = nil) async throws {
		try await frame.hover(selector, timeout: timeout)
	}

	/// Focuses the element.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-focus
	public func focus() async throws {
		try await frame.focus(selector)
	}

	/// Removes focus from the element.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-blur
	public func blur() async throws {
		try await frame.blur(selector)
	}

	/// Selects an option in a `<select>` element by value.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-select-option
	public func selectOption(_ value: String, timeout: Duration? = nil) async throws {
		try await frame.selectOption(selector, values: [value], timeout: timeout)
	}

	/// Selects multiple options in a `<select>` element by value.
	public func selectOption(_ values: [String], timeout: Duration? = nil) async throws {
		try await frame.selectOption(selector, values: values, timeout: timeout)
	}

	/// Taps the element (for touch-based interactions).
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-tap
	public func tap(timeout: Duration? = nil) async throws {
		try await frame.tap(selector, timeout: timeout)
	}

	// MARK: - Queries

	/// Returns the element's text content.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-text-content
	public func textContent(timeout: Duration? = nil) async throws -> String? {
		try await frame.textContent(selector, timeout: timeout)
	}

	/// Returns the element's inner text.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-inner-text
	public func innerText(timeout: Duration? = nil) async throws -> String {
		try await frame.innerText(selector, timeout: timeout)
	}

	/// Returns the element's inner HTML.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-inner-html
	public func innerHTML(timeout: Duration? = nil) async throws -> String {
		try await frame.innerHTML(selector, timeout: timeout)
	}

	/// Returns the value of the given attribute.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-get-attribute
	public func getAttribute(_ name: String, timeout: Duration? = nil) async throws -> String? {
		try await frame.getAttribute(selector, name: name, timeout: timeout)
	}

	/// Returns the input value.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-input-value
	public func inputValue(timeout: Duration? = nil) async throws -> String {
		try await frame.inputValue(selector, timeout: timeout)
	}

	/// Returns the number of elements matching this locator.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-count
	public func count() async throws -> Int {
		try await frame.queryCount(selector)
	}

	// MARK: - State Checks

	/// Returns whether the element is visible.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-is-visible
	public func isVisible() async throws -> Bool {
		try await frame.isVisible(selector)
	}

	/// Returns whether the element is hidden.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-is-hidden
	public func isHidden() async throws -> Bool {
		try await !frame.isVisible(selector)
	}

	/// Returns whether the element is enabled.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-is-enabled
	public func isEnabled() async throws -> Bool {
		try await frame.isEnabled(selector)
	}

	/// Returns whether the element is disabled.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-is-disabled
	public func isDisabled() async throws -> Bool {
		try await !frame.isEnabled(selector)
	}

	/// Returns whether the checkbox/radio is checked.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-is-checked
	public func isChecked() async throws -> Bool {
		try await frame.isChecked(selector)
	}

	/// Returns whether the element is editable.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-is-editable
	public func isEditable() async throws -> Bool {
		try await frame.isEditable(selector)
	}

	// MARK: - Screenshots

	/// Captures a screenshot of the element.
	///
	/// See: https://playwright.dev/docs/api/class-locator#locator-screenshot
	public func screenshot(
		type: ImageType? = nil, quality: Int? = nil, omitBackground: Bool? = nil,
		timeout: Duration? = nil, path: String? = nil
	) async throws -> Data {
		let deadline = ContinuousClock.now + (timeout ?? defaultTimeout)
		let handle = try await frame.waitForSelector(selector, timeout: timeout)
		let remaining = max(deadline - .now, .zero)

		defer { Task { try? await handle.dispose() } }
		return try await handle.screenshot(type: type, quality: quality, omitBackground: omitBackground, timeout: remaining, path: path)
	}
}

extension Locator: CustomStringConvertible, Equatable {
	public var description: String {
		"Locator(\(selector))"
	}

	public static func == (lhs: Locator, rhs: Locator) -> Bool {
		lhs.frame === rhs.frame && lhs.selector == rhs.selector
	}
}
