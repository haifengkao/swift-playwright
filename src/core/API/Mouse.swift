import Foundation

/// Provides methods for simulating mouse input.
///
/// Access via `page.mouse`. All methods send commands on the Page channel.
///
/// See: https://playwright.dev/docs/api/class-mouse
public final class Mouse: Sendable {
	private let page: Page

	init(_ page: Page) {
		self.page = page
	}

	/// Clicks at the given coordinates.
	///
	/// See: https://playwright.dev/docs/api/class-mouse#mouse-click
	public func click(x: Double, y: Double, button: MouseButton? = nil, clickCount: Int? = nil, delay: Duration? = nil) async throws {
		var params: [String: Any] = ["x": x, "y": y]
		if let button { params["button"] = button.rawValue }
		if let delay { params["delay"] = delay.milliseconds }
		if let clickCount { params["clickCount"] = clickCount }

		_ = try await page.send("mouseClick", params: params)
	}

	/// Double-clicks at the given coordinates.
	///
	/// See: https://playwright.dev/docs/api/class-mouse#mouse-dblclick
	public func dblclick(x: Double, y: Double, button: MouseButton? = nil, delay: Duration? = nil) async throws {
		try await click(x: x, y: y, button: button, clickCount: 2, delay: delay)
	}

	/// Moves the mouse to the given coordinates.
	///
	/// See: https://playwright.dev/docs/api/class-mouse#mouse-move
	public func move(x: Double, y: Double, steps: Int? = nil) async throws {
		var params: [String: Any] = ["x": x, "y": y]
		if let steps { params["steps"] = steps }

		_ = try await page.send("mouseMove", params: params)
	}

	/// Dispatches a `mousedown` event.
	///
	/// See: https://playwright.dev/docs/api/class-mouse#mouse-down
	public func down(button: MouseButton? = nil, clickCount: Int? = nil) async throws {
		var params: [String: Any] = [:]
		if let button { params["button"] = button.rawValue }
		if let clickCount { params["clickCount"] = clickCount }

		_ = try await page.send("mouseDown", params: params)
	}

	/// Dispatches a `mouseup` event.
	///
	/// See: https://playwright.dev/docs/api/class-mouse#mouse-up
	public func up(button: MouseButton? = nil, clickCount: Int? = nil) async throws {
		var params: [String: Any] = [:]
		if let button { params["button"] = button.rawValue }
		if let clickCount { params["clickCount"] = clickCount }

		_ = try await page.send("mouseUp", params: params)
	}

	/// Dispatches a `wheel` event to scroll.
	///
	/// See: https://playwright.dev/docs/api/class-mouse#mouse-wheel
	public func wheel(deltaX: Double, deltaY: Double) async throws {
		_ = try await page.send("mouseWheel", params: ["deltaX": deltaX, "deltaY": deltaY])
	}
}
