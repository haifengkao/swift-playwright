import Foundation

/// Default timeout for Playwright operations (30 seconds).
let defaultTimeout: Duration = .seconds(30)

/// Returns the timeout in milliseconds, falling back to the default timeout.
func timeoutMs(_ timeout: Duration? = nil) -> Double {
	(timeout ?? defaultTimeout).milliseconds
}

/// Parses headers from the server's array-of-dicts format to a flat dictionary.
///
/// Duplicate header names are merged: values are joined with `", "` for
/// standard headers and `"\n"` for `set-cookie`.
func parseHeaders(_ raw: Any?) -> [String: String] {
	guard let array = raw as? [[String: Any]] else { return [:] }

	var result: [String: String] = [:]
	for entry in array {
		guard let name = entry["name"] as? String, let value = entry["value"] as? String else { continue }
		let key = name.lowercased()
		let separator = key == "set-cookie" ? "\n" : ", "
		result[key] = result[key].map { "\($0)\(separator)\(value)" } ?? value
	}

	return result
}

/// Decodes a base64-encoded binary result from the server into `Data`.
func decodeBase64Binary(_ result: [String: Any], key: String = "binary") throws -> Data {
	guard let binary = result[key] as? String, let data = Data(base64Encoded: binary) else {
		throw PlaywrightError.serverError("Failed to decode \(key) data")
	}

	return data
}

/// Infers screenshot format from the file path extension.
///
/// Matches playwright-python/dotnet behavior: throws on unsupported extensions.
private func inferScreenshotType(from path: String) throws -> ImageType {
	switch URL(fileURLWithPath: path).pathExtension.lowercased() {
		case "png": return .png
		case "jpg", "jpeg": return .jpeg
		default: throw PlaywrightError.invalidArgument(
				"Unsupported screenshot format for path \"\(path)\". Use .png or .jpeg extension, or set type explicitly."
			)
	}
}

/// Builds common screenshot params shared by Page and ElementHandle.
/// Note: `fullPage` is intentionally excluded — it only applies to Page screenshots.
///
/// When `type` is nil, infers the format from `path` (if provided), defaulting to PNG.
func screenshotParams(
	type explicitType: ImageType? = nil, quality: Int? = nil,
	omitBackground: Bool? = nil, timeout: Duration? = nil, path: String? = nil
) throws -> [String: Any] {
	let type: ImageType
	if let explicitType { type = explicitType }
	else if let path { type = try inferScreenshotType(from: path) }
	else { type = .png }

	var params: [String: Any] = [
		"type": type.rawValue,
		"timeout": timeoutMs(timeout),
	]
	if let quality { params["quality"] = quality }
	if let omitBackground { params["omitBackground"] = omitBackground }

	return params
}

/// Decodes screenshot result and optionally saves to disk.
func processScreenshotResult(_ result: [String: Any], path: String?) throws -> Data {
	let data = try decodeBase64Binary(result)

	if let path {
		let url = URL(fileURLWithPath: path)
		try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try data.write(to: url)
	}

	return data
}
