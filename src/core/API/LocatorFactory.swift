/// Protocol for types that can create locators (Page, Frame, Locator).
///
/// Provides default implementations for all `getBy*` methods based on
/// the single required `locator(_:)` method.
public protocol LocatorFactory {
	/// Creates a locator for elements matching the given selector.
	func locator(_ selector: String) -> Locator

	/// Finds elements by their text content.
	func getByText(_ text: String, exact: Bool) -> Locator

	/// Finds elements by their ARIA role.
	func getByRole(_ role: AriaRole, options: GetByRoleOptions?) -> Locator

	/// Finds elements by their test ID.
	func getByTestId(_ testId: String) -> Locator

	/// Finds elements by their associated label.
	func getByLabel(_ text: String, exact: Bool) -> Locator

	/// Finds elements by their placeholder text.
	func getByPlaceholder(_ text: String, exact: Bool) -> Locator

	/// Finds elements by their alt text.
	func getByAltText(_ text: String, exact: Bool) -> Locator

	/// Finds elements by their title attribute.
	func getByTitle(_ text: String, exact: Bool) -> Locator
}

public extension LocatorFactory {
	func getByText(_ text: String, exact: Bool = false) -> Locator {
		locator(SelectorBuilder.textSelector(text, exact: exact))
	}

	func getByRole(_ role: AriaRole, options: GetByRoleOptions? = nil) -> Locator {
		locator(SelectorBuilder.roleSelector(role, options: options))
	}

	func getByTestId(_ testId: String) -> Locator {
		locator(SelectorBuilder.testIdSelector(testId))
	}

	func getByLabel(_ text: String, exact: Bool = false) -> Locator {
		locator(SelectorBuilder.labelSelector(text, exact: exact))
	}

	func getByPlaceholder(_ text: String, exact: Bool = false) -> Locator {
		locator(SelectorBuilder.attributeSelector("placeholder", text: text, exact: exact))
	}

	func getByAltText(_ text: String, exact: Bool = false) -> Locator {
		locator(SelectorBuilder.attributeSelector("alt", text: text, exact: exact))
	}

	func getByTitle(_ text: String, exact: Bool = false) -> Locator {
		locator(SelectorBuilder.attributeSelector("title", text: text, exact: exact))
	}
}
