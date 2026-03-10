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

	/// Releases this handle, allowing the server to garbage-collect the
	/// underlying DOM reference.
	///
	/// See: https://playwright.dev/docs/api/class-elementhandle#element-handle-dispose
	func dispose() async throws {
		_ = try await send("dispose")
	}
}
