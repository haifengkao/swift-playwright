import Foundation

/// Represents a network request sent by the browser.
///
/// Request objects are created by the server when navigation or resource
/// loading occurs. They are immutable snapshots of the request parameters.
///
/// See: https://playwright.dev/docs/api/class-request
public final class Request: ChannelOwner, @unchecked Sendable {
	/// The URL of the request.
	public let url: String

	/// The HTTP method (GET, POST, etc.).
	public let method: String

	/// The request headers as a dictionary.
	public let headers: [String: String]

	/// The resource type (document, stylesheet, image, etc.).
	public let resourceType: String

	/// Whether this request is a navigation request.
	public let isNavigationRequest: Bool

	/// The POST data, if any.
	public let postData: Data?

	override init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		url = initializer["url"] as? String ?? ""
		method = initializer["method"] as? String ?? "GET"
		resourceType = initializer["resourceType"] as? String ?? ""
		isNavigationRequest = initializer["isNavigationRequest"] as? Bool ?? false

		if let postDataBase64 = initializer["postData"] as? String {
			postData = Data(base64Encoded: postDataBase64)
		} else {
			postData = nil
		}

		headers = parseHeaders(initializer["headers"])

		super.init(connection: connection, parent: parent, type: type, guid: guid, initializer: initializer)
	}
}

extension Request: CustomStringConvertible {
	public var description: String {
		"\(method) \(url)"
	}
}
