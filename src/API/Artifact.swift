import Foundation

/// Represents a server-side file artifact (used for downloads).
///
/// See: https://playwright.dev/docs/api/class-artifact
public final class Artifact: ChannelOwner, @unchecked Sendable {
	/// Returns the path to the downloaded file after it finishes.
	///
	/// See: https://playwright.dev/docs/api/class-artifact#artifact-path-after-finished
	public func pathAfterFinished() async throws -> String {
		let result = try await send("pathAfterFinished")
		return result["value"] as? String ?? ""
	}

	/// Saves the artifact to the specified path.
	///
	/// See: https://playwright.dev/docs/api/class-artifact#artifact-save-as
	public func saveAs(_ path: String) async throws {
		_ = try await send("saveAs", params: ["path": path])
	}

	/// Returns the error string if the download failed, or `nil` if successful.
	///
	/// See: https://playwright.dev/docs/api/class-artifact#artifact-failure
	public func failure() async throws -> String? {
		let result = try await send("failure")
		return result["error"] as? String
	}

	/// Cancels the in-progress download.
	///
	/// See: https://playwright.dev/docs/api/class-artifact#artifact-cancel
	public func cancel() async throws {
		_ = try await send("cancel")
	}

	/// Deletes the downloaded artifact.
	///
	/// See: https://playwright.dev/docs/api/class-artifact#artifact-delete
	public func delete() async throws {
		_ = try await send("delete")
	}
}
