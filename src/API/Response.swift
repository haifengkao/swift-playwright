import Foundation
import Synchronization

/// Represents a network response received by the browser.
///
/// Response objects are created by the server during navigation and resource loading.
/// They provide access to the response status, headers, and body content.
///
/// See: https://playwright.dev/docs/api/class-response
public final class Response: ChannelOwner, @unchecked Sendable {
	/// The URL of the response.
	public let url: String

	/// The HTTP status code (e.g. 200, 404).
	public let status: Int

	/// The HTTP status text (e.g. "OK", "Not Found").
	public let statusText: String

	/// The response headers as a dictionary.
	public let headers: [String: String]

	/// Whether the response status is in the 2xx range (or 0 for local resources).
	public var ok: Bool { status == 0 || (200...299).contains(status) }

	/// The request that produced this response.
	///
	/// Resolved after creation via `didCreate(resolve:)`. Always set once
	/// the object is fully initialized — only nil if the server sent invalid data.
	/// Safe to read without synchronization: written once in `didCreate` (called
	/// synchronously during Connection dispatch) before user code can access it.
	public private(set) var request: Request?

	private struct State: ~Copyable {
		var bodyTask: Task<Data, Error>?
	}

	private let state = Mutex(State())

	override init(connection: Connection, parent: ChannelOwner?, type: String, guid: String, initializer: [String: Any]) {
		url = initializer["url"] as? String ?? ""
		status = initializer["status"] as? Int ?? 0
		statusText = initializer["statusText"] as? String ?? ""
		headers = parseHeaders(initializer["headers"])

		super.init(connection: connection, parent: parent, type: type, guid: guid, initializer: initializer)
	}

	override func didCreate(resolve: (String) -> ChannelOwner?) {
		guard let requestRef = initializer["request"] as? [String: Any],
		      let requestGuid = requestRef["guid"] as? String,
		      let req = resolve(requestGuid) as? Request
		else {
			assertionFailure("Response created without a valid Request reference")
			return
		}

		request = req
	}

	/// Returns the response body as raw bytes.
	///
	/// - Throws: `PlaywrightError` if the body could not be fetched.
	///
	/// See: https://playwright.dev/docs/api/class-response#response-body
	public func body() async throws -> Data {
		let task = state.withLock { state -> Task<Data, Error> in
			if let existing = state.bodyTask { return existing }
			let task = Task { [self] in
				let result = try await send("body")
				return try decodeBase64Binary(result)
			}
			state.bodyTask = task
			return task
		}

		return try await task.value
	}

	/// Returns the response body as a UTF-8 string.
	///
	/// - Throws: `PlaywrightError` if the body could not be fetched or decoded.
	///
	/// See: https://playwright.dev/docs/api/class-response#response-text
	public func text() async throws -> String {
		let data = try await body()
		return String(decoding: data, as: UTF8.self)
	}

	/// Returns the response body parsed as JSON.
	///
	/// - Throws: `PlaywrightError` if the body could not be fetched or parsed.
	///
	/// See: https://playwright.dev/docs/api/class-response#response-json
	public func json() async throws -> Any {
		try JSONSerialization.jsonObject(with: await body(), options: .fragmentsAllowed)
	}
}

extension Response: CustomStringConvertible {
	public var description: String {
		"\(status) \(statusText) \(url)"
	}
}
