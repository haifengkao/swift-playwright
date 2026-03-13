import Foundation

/// The type of a browser dialog.
public enum DialogType: String, Sendable {
	case alert, confirm, prompt, beforeunload
}

/// Represents a browser dialog (alert, confirm, prompt, beforeunload).
///
/// Dialogs are dispatched by the server and must be accepted or dismissed.
/// If no listener is attached, dialogs are auto-dismissed.
///
/// See: https://playwright.dev/docs/api/class-dialog
public final class Dialog: ChannelOwner, @unchecked Sendable {
	/// The page that initiated this dialog, if available.
	///
	/// See: https://playwright.dev/docs/api/class-dialog#dialog-page
	public internal(set) var page: Page?

	/// The dialog type.
	public let dialogType: DialogType

	/// The dialog message text.
	public let message: String

	/// The default value for prompt dialogs (empty string for other types).
	public let defaultValue: String

	override init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		page = initializer["page"] as? Page
		message = initializer["message"] as? String ?? ""
		defaultValue = initializer["defaultValue"] as? String ?? ""
		dialogType = (initializer["type"] as? String).flatMap(DialogType.init) ?? .alert

		super.init(connection: connection, parent: parent, type: type, guid: guid, initializer: initializer)
	}

	/// Accepts the dialog.
	///
	/// - Parameter promptText: For prompt dialogs, the text to enter. Ignored for other dialog types.
	///
	/// See: https://playwright.dev/docs/api/class-dialog#dialog-accept
	public func accept(promptText: String? = nil) async throws {
		var params: [String: Any] = [:]
		if let promptText { params["promptText"] = promptText }
		_ = try await send("accept", params: params)
	}

	/// Dismisses the dialog.
	///
	/// See: https://playwright.dev/docs/api/class-dialog#dialog-dismiss
	public func dismiss() async throws {
		_ = try await send("dismiss")
	}
}
