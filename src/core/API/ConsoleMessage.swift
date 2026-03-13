import Foundation

/// The type of console message.
public enum ConsoleType: String, Sendable {
	case log, error, warning, info, debug, trace, dir,
	     dirxml, table, count, assert, clear, profile,
	     profileEnd, startGroup, startGroupCollapsed,
	     endGroup, time, timeEnd
}

/// Source location of a console message.
public struct ConsoleMessageLocation: Sendable {
	/// The URL of the script that generated the console message.
	public let url: String

	/// The line number in the source (0-based).
	public let lineNumber: Int

	/// The column number in the source (0-based).
	public let columnNumber: Int
}

/// Represents a console message emitted by the page via `console.log()`, `console.error()`, etc.
///
/// Console messages are event-based (mixin in the protocol), not separate ChannelOwner objects.
/// They are constructed client-side from the event parameters.
///
/// ```swift
/// await page.onConsole { message in
///     print("\(message.consoleType): \(message.text)")
/// }
/// ```
///
/// See: https://playwright.dev/docs/api/class-consolemessage
public struct ConsoleMessage: Sendable {
	/// The type of the console message (log, error, warning, etc.).
	public let consoleType: ConsoleType

	/// The text of the console message.
	public let text: String

	/// The source location where the message was generated.
	public let location: ConsoleMessageLocation

	/// The page that produced this message, if any.
	///
	/// This is `nil` for messages from service workers.
	///
	/// See: https://playwright.dev/docs/api/class-consolemessage#console-message-page
	public let page: Page?

	init(params: [String: Any]) {
		page = params["page"] as? Page
		text = params["text"] as? String ?? ""
		consoleType = (params["type"] as? String).flatMap(ConsoleType.init) ?? .log

		if let loc = params["location"] as? [String: Any] {
			location = ConsoleMessageLocation(
				url: loc["url"] as? String ?? "",
				lineNumber: loc["lineNumber"] as? Int ?? 0,
				columnNumber: loc["columnNumber"] as? Int ?? 0
			)
		} else {
			location = ConsoleMessageLocation(url: "", lineNumber: 0, columnNumber: 0)
		}
	}
}
