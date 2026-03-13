import Foundation
import Synchronization

/// Represents a frame within a page (main frame or iframe).
///
/// At minimum, each page has a main frame. The frame tracks the
/// current URL, name, and load state.
///
/// See: https://playwright.dev/docs/api/class-frame
public final class Frame: ChannelOwner, LocatorFactory, @unchecked Sendable {
	private struct State: ~Copyable {
		var url: String
		var name: String
		weak var page: Page?
		var loadStates: Set<String>
	}

	private let state: Mutex<State>

	/// The frame's name attribute.
	public var name: String {
		state.withLock { $0.name }
	}

	/// The current URL of the frame.
	public var url: String {
		state.withLock { $0.url }
	}

	/// The current load states of the frame.
	var loadStates: Set<String> {
		state.withLock { $0.loadStates }
	}

	/// Back-reference to the owning page (set by Page.init).
	var page: Page? {
		get { state.withLock { $0.page } }
		set { state.withLock { $0.page = newValue } }
	}

	override init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		let initialLoadStates = (initializer["loadStates"] as? [String]).map(Set.init) ?? []

		state = Mutex(State(
			url: initializer["url"] as? String ?? "",
			name: initializer["name"] as? String ?? "",
			loadStates: initialLoadStates
		))

		super.init(connection: connection, parent: parent, type: type, guid: guid, initializer: initializer)

		on("navigated") { [weak self] params in
			guard let self else { return }
			self.state.withLock { state in
				if let url = params["url"] as? String { state.url = url }
				if let name = params["name"] as? String { state.name = name }
			}
		}

		on("loadstate") { [weak self] params in
			guard let self else { return }
			let add = params["add"] as? String
			let remove = params["remove"] as? String

			let page = self.state.withLock { state -> Page? in
				if let add { state.loadStates.insert(add) }
				if let remove { state.loadStates.remove(remove) }
				return state.page
			}

			// Bubble load events to Page (if this is the main frame).
			if let page, let add, add == "load" || add == "domcontentloaded" {
				page.emit(add, params: [:])
			}
		}
	}

	// MARK: - Locators

	/// Creates a locator for elements matching the given CSS or Playwright selector.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-locator
	public func locator(_ selector: String) -> Locator {
		Locator(self, selector: selector)
	}

	// MARK: - Navigation

	/// Navigates the frame to the specified URL.
	///
	/// - Parameter url: The URL to navigate to.
	/// - Parameter timeout: Maximum time to wait. Defaults to 30 seconds.
	/// - Parameter waitUntil: When to consider the operation as finished.
	/// - Parameter referer: Referer header to set for navigation.
	/// - Returns: The main resource response, or `nil` for data URLs and `about:blank`.
	/// - Throws: `PlaywrightError` if navigation fails or times out.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-goto
	@discardableResult
	public func goto(_ url: String, timeout: Duration? = nil, waitUntil: WaitUntilState? = nil, referer: String? = nil) async throws -> Response? {
		var params: [String: Any] = [
			"url": url,
			"timeout": timeoutMs(timeout),
		]
		if let referer { params["referer"] = referer }
		if let waitUntil { params["waitUntil"] = waitUntil.rawValue }

		return try await sendAndResolveOptional("goto", params: params, key: "response")
	}

	/// Returns the page title.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-title
	public func title() async throws -> String {
		let result = try await send("title")
		return result["value"] as? String ?? ""
	}

	/// Returns the full HTML content of the frame, including the doctype.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-content
	public func content() async throws -> String {
		let result = try await send("content")
		return result["value"] as? String ?? ""
	}

	/// Sets the HTML content of the frame.
	///
	/// - Parameter html: The HTML markup to set.
	/// - Parameter timeout: Maximum time to wait. Defaults to 30 seconds.
	/// - Parameter waitUntil: When to consider the operation as finished.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-set-content
	public func setContent(_ html: String, timeout: Duration? = nil, waitUntil: WaitUntilState? = nil) async throws {
		var params: [String: Any] = [
			"html": html,
			"timeout": timeoutMs(timeout),
		]
		if let waitUntil { params["waitUntil"] = waitUntil.rawValue }

		_ = try await send("setContent", params: params)
	}

	// MARK: - Helpers

	private func selectorParams(_ selector: String, strict: Bool = true, timeout: Duration? = nil) -> [String: Any] {
		["selector": selector, "strict": strict, "timeout": timeoutMs(timeout)]
	}

	/// Sends a simple action that only needs selector params (no extra parameters).
	private func selectorAction(_ method: String, _ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws {
		_ = try await send(method, params: selectorParams(selector, strict: strict, timeout: timeout))
	}

	/// Sends a query and returns `result["value"]` cast to `T`, or `fallback` if missing.
	private func queryValue<T>(_ method: String, _ selector: String, strict: Bool = true, timeout: Duration? = nil, fallback: T) async throws -> T {
		let result = try await send(method, params: selectorParams(selector, strict: strict, timeout: timeout))
		return result["value"] as? T ?? fallback
	}

	// MARK: - Actions (internal, called by Locator)

	private func clickAction(
		_ method: String,
		_ selector: String,
		strict: Bool = true,
		button: MouseButton? = nil,
		clickCount: Int? = nil,
		delay: Duration? = nil,
		force: Bool? = nil,
		modifiers: [KeyboardModifier]? = nil,
		position: Position? = nil,
		timeout: Duration? = nil,
		trial: Bool? = nil
	) async throws {
		var params = selectorParams(selector, strict: strict, timeout: timeout)
		if let force { params["force"] = force }
		if let trial { params["trial"] = trial }
		if let button { params["button"] = button.rawValue }
		if let delay { params["delay"] = delay.milliseconds }
		if let clickCount { params["clickCount"] = clickCount }
		if let position { params["position"] = position.toParams() }
		if let modifiers { params["modifiers"] = modifiers.map(\.rawValue) }

		_ = try await send(method, params: params)
	}

	func click(
		_ selector: String, strict: Bool = true,
		button: MouseButton? = nil, clickCount: Int? = nil,
		delay: Duration? = nil, force: Bool? = nil,
		modifiers: [KeyboardModifier]? = nil, position: Position? = nil,
		timeout: Duration? = nil, trial: Bool? = nil
	) async throws {
		try await clickAction("click", selector, strict: strict, button: button, clickCount: clickCount, delay: delay, force: force, modifiers: modifiers, position: position, timeout: timeout, trial: trial)
	}

	func dblclick(
		_ selector: String, strict: Bool = true,
		button: MouseButton? = nil, delay: Duration? = nil,
		force: Bool? = nil, modifiers: [KeyboardModifier]? = nil, position: Position? = nil,
		timeout: Duration? = nil, trial: Bool? = nil
	) async throws {
		try await clickAction("dblclick", selector, strict: strict, button: button, delay: delay, force: force, modifiers: modifiers, position: position, timeout: timeout, trial: trial)
	}

	func fill(_ selector: String, value: String, strict: Bool = true, force: Bool? = nil, timeout: Duration? = nil) async throws {
		var params = selectorParams(selector, strict: strict, timeout: timeout)
		params["value"] = value
		if let force { params["force"] = force }

		_ = try await send("fill", params: params)
	}

	func press(_ selector: String, key: String, strict: Bool = true, timeout: Duration? = nil) async throws {
		var params = selectorParams(selector, strict: strict, timeout: timeout)
		params["key"] = key

		_ = try await send("press", params: params)
	}

	func pressSequentially(_ selector: String, text: String, strict: Bool = true, timeout: Duration? = nil) async throws {
		var params = selectorParams(selector, strict: strict, timeout: timeout)
		params["text"] = text

		_ = try await send("type", params: params)
	}

	func check(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws {
		try await selectorAction("check", selector, strict: strict, timeout: timeout)
	}

	func uncheck(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws {
		try await selectorAction("uncheck", selector, strict: strict, timeout: timeout)
	}

	func setChecked(_ selector: String, checked: Bool, strict: Bool = true, timeout: Duration? = nil) async throws {
		if checked { try await check(selector, strict: strict, timeout: timeout) }
		else { try await uncheck(selector, strict: strict, timeout: timeout) }
	}

	func hover(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws {
		try await selectorAction("hover", selector, strict: strict, timeout: timeout)
	}

	func focus(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws {
		try await selectorAction("focus", selector, strict: strict, timeout: timeout)
	}

	func blur(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws {
		try await selectorAction("blur", selector, strict: strict, timeout: timeout)
	}

	func selectOption(_ selector: String, values: [String], strict: Bool = true, timeout: Duration? = nil) async throws {
		var params = selectorParams(selector, strict: strict, timeout: timeout)
		params["options"] = values.map { ["valueOrLabel": $0] }

		_ = try await send("selectOption", params: params)
	}

	func tap(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws {
		try await selectorAction("tap", selector, strict: strict, timeout: timeout)
	}

	// MARK: - Queries (internal, called by Locator)

	func textContent(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws -> String? {
		let result = try await send("textContent", params: selectorParams(selector, strict: strict, timeout: timeout))
		return result["value"] as? String
	}

	func innerText(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws -> String {
		try await queryValue("innerText", selector, strict: strict, timeout: timeout, fallback: "")
	}

	func innerHTML(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws -> String {
		try await queryValue("innerHTML", selector, strict: strict, timeout: timeout, fallback: "")
	}

	func getAttribute(_ selector: String, name: String, strict: Bool = true, timeout: Duration? = nil) async throws -> String? {
		var params = selectorParams(selector, strict: strict, timeout: timeout)
		params["name"] = name

		let result = try await send("getAttribute", params: params)
		return result["value"] as? String
	}

	func inputValue(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws -> String {
		try await queryValue("inputValue", selector, strict: strict, timeout: timeout, fallback: "")
	}

	func queryCount(_ selector: String) async throws -> Int {
		let result = try await send("queryCount", params: ["selector": selector])
		return result["value"] as? Int ?? 0
	}

	func isVisible(_ selector: String, strict: Bool = true) async throws -> Bool {
		let result = try await send("isVisible", params: ["selector": selector, "strict": strict])
		return result["value"] as? Bool ?? false
	}

	func isEnabled(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws -> Bool {
		try await queryValue("isEnabled", selector, strict: strict, timeout: timeout, fallback: false)
	}

	func isChecked(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws -> Bool {
		try await queryValue("isChecked", selector, strict: strict, timeout: timeout, fallback: false)
	}

	func isEditable(_ selector: String, strict: Bool = true, timeout: Duration? = nil) async throws -> Bool {
		try await queryValue("isEditable", selector, strict: strict, timeout: timeout, fallback: false)
	}

	/// Waits for an element matching the selector to appear in the DOM.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-wait-for-selector
	public func waitForSelector(_ selector: String, state: WaitForSelectorState = .visible, strict: Bool = false, timeout: Duration? = nil) async throws -> ElementHandle? {
		var params = selectorParams(selector, strict: strict, timeout: timeout)
		params["state"] = state.rawValue

		return try await sendAndResolveOptional("waitForSelector", params: params, key: "element")
	}

	/// Returns the first element matching the selector, or `nil` if no elements match.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-query-selector
	public func querySelector(_ selector: String, strict: Bool? = nil) async throws -> ElementHandle? {
		var params: [String: Any] = ["selector": selector]
		if let strict { params["strict"] = strict }

		return try await sendAndResolveOptional("querySelector", params: params, key: "element")
	}

	/// Returns all elements matching the selector.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-query-selector-all
	public func querySelectorAll(_ selector: String) async throws -> [ElementHandle] {
		let result = try await send("querySelectorAll", params: ["selector": selector])
		return await connection.resolveArray(from: result, key: "elements")
	}

	/// Waits for the given duration (protocol-level sleep).
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-wait-for-timeout
	public func waitForTimeout(_ timeout: Duration) async throws {
		_ = try await send("waitForTimeout", params: ["waitTimeout": timeout.milliseconds])
	}

	// MARK: - Evaluate

	/// Evaluates a JavaScript expression in the frame's context.
	///
	/// - Parameter expression: The JavaScript expression to evaluate.
	/// - Parameter arg: Optional argument to pass to the expression.
	/// - Returns: The result of the evaluation, or `nil` for JavaScript `null`/`undefined`.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-evaluate
	@_disfavoredOverload
	public func evaluate(_ expression: String, arg: Any? = nil) async throws -> Any? {
		nonisolated(unsafe) let params: [String: Any] = try [
			"expression": expression,
			"arg": EvaluateSerializer.serializeArgument(arg),
		]

		let result = try await send("evaluateExpression", params: params)
		return EvaluateSerializer.parseResult(result["value"])
	}

	/// Type-safe variant that casts the result to the expected type.
	///
	/// ```swift
	/// let count: Int = try await frame.evaluate("document.querySelectorAll('a').length")
	/// ```
	///
	/// - Throws: `PlaywrightError.invalidArgument` if the result cannot be cast to `T`.
	///
	/// See: https://playwright.dev/docs/api/class-frame#frame-evaluate
	public func evaluate<T>(_ expression: String, arg: Any? = nil) async throws -> T {
		guard let result = try await evaluate(expression, arg: arg) as? T else {
			throw PlaywrightError.invalidArgument("Expected evaluate result of type \(T.self)")
		}

		return result
	}

	/// Evaluates a JavaScript expression on all elements matching the selector.
	///
	/// - Parameter selector: The selector to match elements.
	/// - Parameter expression: The JavaScript expression to evaluate.
	/// - Parameter arg: Optional argument to pass to the expression.
	/// - Returns: The result of the evaluation.
	func evalOnSelectorAll(_ selector: String, expression: String, arg: Any? = nil) async throws -> Any? {
		nonisolated(unsafe) let params: [String: Any] = try [
			"selector": selector,
			"expression": expression,
			"arg": EvaluateSerializer.serializeArgument(arg),
		]

		let result = try await send("evalOnSelectorAll", params: params)
		return EvaluateSerializer.parseResult(result["value"])
	}
}

extension Frame: CustomStringConvertible {
	public var description: String {
		state.withLock { $0.name.isEmpty ? "Frame(\($0.url))" : "Frame(\($0.name))" }
	}
}
