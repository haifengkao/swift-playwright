import Foundation

/// Represents a file download initiated by the page.
///
/// Download objects are received via the `page.onDownload` handler.
/// Each download wraps a server-side Artifact that manages the temp file.
///
/// ```swift
/// page.onDownload { download in
///     print(download.suggestedFilename) // "report.pdf"
///     try await download.saveAs("/tmp/report.pdf")
/// }
/// ```
///
/// See: https://playwright.dev/docs/api/class-download
public struct Download: Sendable {
	/// The URL of the download.
	public let url: String

	/// The suggested filename for the download.
	public let suggestedFilename: String

	/// The underlying artifact managing the server-side temp file.
	private let artifact: Artifact

	init(url: String, suggestedFilename: String, artifact: Artifact) {
		self.url = url
		self.artifact = artifact
		self.suggestedFilename = suggestedFilename
	}

	/// Returns the path to the downloaded file after it finishes.
	///
	/// See: https://playwright.dev/docs/api/class-download#download-path
	public func path() async throws -> String {
		try await artifact.pathAfterFinished()
	}

	/// Saves the download to the specified path.
	///
	/// See: https://playwright.dev/docs/api/class-download#download-save-as
	public func saveAs(_ path: String) async throws {
		try await artifact.saveAs(path)
	}

	/// Returns the error string if the download failed, or `nil` if successful.
	///
	/// See: https://playwright.dev/docs/api/class-download#download-failure
	public func failure() async throws -> String? {
		try await artifact.failure()
	}

	/// Cancels the in-progress download.
	///
	/// See: https://playwright.dev/docs/api/class-download#download-cancel
	public func cancel() async throws {
		try await artifact.cancel()
	}

	/// Deletes the downloaded artifact.
	///
	/// See: https://playwright.dev/docs/api/class-download#download-delete
	public func delete() async throws {
		try await artifact.delete()
	}
}
