import Foundation

/// Represents an intercepted network request route.
///
/// Route objects are dispatched when a network request matches a registered
/// pattern via `page.route()`. Each route must be resolved by calling
/// exactly one of `abort()`, `continue_()`, or `fulfill()`.
///
/// See: https://playwright.dev/docs/api/class-route
public final class Route: ChannelOwner, @unchecked Sendable {
	/// The intercepted request.
	public private(set) var request: Request?

	override func didCreate(resolve: (String) -> ChannelOwner?) {
		guard let ref = initializer["request"] as? [String: Any],
		      let guid = ref["guid"] as? String,
		      let req = resolve(guid) as? Request
		else {
			return assertionFailure("Route created without a valid Request reference")
		}

		request = req
	}

	/// Aborts the request.
	///
	/// See: https://playwright.dev/docs/api/class-route#route-abort
	public func abort(errorCode: String? = nil) async throws {
		var params: [String: Any] = [:]
		if let errorCode { params["errorCode"] = errorCode }

		_ = try await send("abort", params: params)
	}

	/// Continues the request, optionally with modifications.
	///
	/// See: https://playwright.dev/docs/api/class-route#route-continue
	public func continue_(url: String? = nil, method: String? = nil, headers: [String: String]? = nil, postData: Data? = nil) async throws {
		var params: [String: Any] = [:]
		if let url { params["url"] = url }
		if let method { params["method"] = method }
		if let headers { params["headers"] = headers.map { ["name": $0.key, "value": $0.value] } }
		if let postData { params["postData"] = postData.base64EncodedString() }

		_ = try await send("continue", params: params)
	}

	/// Fulfills the request with a custom response.
	///
	/// See: https://playwright.dev/docs/api/class-route#route-fulfill
	public func fulfill(status: Int = 200, headers: [String: String]? = nil, body: String? = nil) async throws {
		var params: [String: Any] = ["status": status, "isBase64": false]
		if let body { params["body"] = body }
		if let headers { params["headers"] = headers.map { ["name": $0.key, "value": $0.value] } }

		_ = try await send("fulfill", params: params)
	}
}
