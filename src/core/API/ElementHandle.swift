import Foundation

/// Represents a handle to a DOM element in the page.
///
/// ElementHandle is a ChannelOwner that wraps a server-side reference
/// to a DOM element. It supports direct operations like screenshots.
///
/// **Note:** In most cases, prefer `Locator` over `ElementHandle`.
/// Locators auto-wait and auto-retry, while ElementHandle refers to a
/// specific DOM element that may become stale.
///
/// See: https://playwright.dev/docs/api/class-elementhandle
public final class ElementHandle: ChannelOwner, @unchecked Sendable {
	/// Captures a screenshot of this element.
	///
	/// - Returns: The screenshot image data.
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-screenshot
	public func screenshot(
		type: ImageType? = nil,
		quality: Int? = nil,
		omitBackground: Bool? = nil,
		timeout: Duration? = nil,
		path: String? = nil
	) async throws -> Data {
		let result = try await send("screenshot", params: screenshotParams(
			type: type, quality: quality, omitBackground: omitBackground, timeout: timeout, path: path
		))

		return try processScreenshotResult(result, path: path)
	}

	/// Returns the first child element matching the selector, or `nil` if no elements match.
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-query-selector
	public func querySelector(_ selector: String) async throws -> ElementHandle? {
		try await sendAndResolveOptional("querySelector", params: ["selector": selector], key: "element")
	}

	/// Returns all child elements matching the selector.
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-query-selector-all
	public func querySelectorAll(_ selector: String) async throws -> [ElementHandle] {
		let result = try await send("querySelectorAll", params: ["selector": selector])
		return await connection.resolveArray(from: result, key: "elements")
	}

	/// Returns the value of the specified attribute, or `nil` if not present.
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-get-attribute
	public func getAttribute(_ name: String) async throws -> String? {
		let result = try await send("getAttribute", params: ["name": name])
		return result["value"] as? String
	}

	/// Returns the rendered inner text of the element.
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-inner-text
	public func innerText() async throws -> String {
		let result = try await send("innerText")
		return result["value"] as? String ?? ""
	}

	/// Returns the raw text content of the element (including hidden text).
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-text-content
	public func textContent() async throws -> String? {
		let result = try await send("textContent")
		return result["value"] as? String
	}

	/// Returns the inner HTML of the element.
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-inner-html
	public func innerHTML() async throws -> String {
		let result = try await send("innerHTML")
		return result["value"] as? String ?? ""
	}

	/// Evaluates a JavaScript expression with this element as the first argument.
	///
	/// ```swift
	/// let tagName = try await elementHandle.evaluate("el => el.tagName") as? String
	/// ```
	///
	/// - Parameter expression: The JavaScript expression to evaluate.
	/// - Parameter arg: Optional argument to pass to the expression.
	/// - Returns: The result of the evaluation, or `nil` for JavaScript `null`/`undefined`.
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-evaluate
	public func evaluate(_ expression: String, arg: Any? = nil) async throws -> Any? {
		nonisolated(unsafe) let params: [String: Any] = try [
			"expression": expression,
			"arg": EvaluateSerializer.serializeArgument(arg),
		]

		let result = try await send("evaluateExpression", params: params)
		return EvaluateSerializer.parseResult(result["value"])
	}

	/// Releases this handle, allowing the server to garbage-collect the
	/// underlying DOM reference.
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-dispose
	func dispose() async throws {
		_ = try await send("dispose")
	}
}
