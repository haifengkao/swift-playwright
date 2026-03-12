import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct DownloadTests {
		@Test("download event fires with correct metadata")
		func downloadEvent() async throws {
			try await withPage { page in
				try await page.setContent("""
					<a id="dl" href="data:text/plain,Hello%20World" download="report.txt">Download</a>
					""")

				let (downloads, continuation) = AsyncStream<Download>.makeStream()
				page.onDownload { download in continuation.yield(download) }

				try await page.locator("#dl").click()

				var iter = downloads.makeAsyncIterator()
				let download = await iter.next()!
				#expect(download.suggestedFilename == "report.txt")
				#expect(download.url.contains("data:text/plain"))
			}
		}

		@Test("download.saveAs saves file to disk")
		func downloadSaveAs() async throws {
			try await withPage { page in
				try await page.setContent("""
					<a id="dl" href="data:text/plain,file%20content%20here" download="data.txt">Download</a>
					""")

				let (downloads, continuation) = AsyncStream<Download>.makeStream()
				page.onDownload { download in continuation.yield(download) }

				try await page.locator("#dl").click()

				var iter = downloads.makeAsyncIterator()
				let download = await iter.next()!

				let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
				defer { try? FileManager.default.removeItem(atPath: tempDir) }

				let dest = tempDir + "/saved.txt"
				try await download.saveAs(dest)

				#expect(FileManager.default.fileExists(atPath: dest))
				let content = try String(contentsOfFile: dest, encoding: .utf8)
				#expect(content == "file content here")
			}
		}

		@Test("download.path returns temp file path")
		func downloadPath() async throws {
			try await withPage { page in
				try await page.setContent("""
					<a id="dl" href="data:text/plain,path%20test" download="path.txt">Download</a>
					""")

				let (downloads, continuation) = AsyncStream<Download>.makeStream()
				page.onDownload { download in continuation.yield(download) }

				try await page.locator("#dl").click()

				var iter = downloads.makeAsyncIterator()
				let download = await iter.next()!

				let path = try await download.path()
				#expect(!path.isEmpty)
				#expect(FileManager.default.fileExists(atPath: path))
			}
		}

		@Test("download.failure returns nil for successful download")
		func downloadFailureNil() async throws {
			try await withPage { page in
				try await page.setContent("""
					<a id="dl" href="data:text/plain,success" download="ok.txt">Download</a>
					""")

				let (downloads, continuation) = AsyncStream<Download>.makeStream()
				page.onDownload { download in continuation.yield(download) }

				try await page.locator("#dl").click()

				var iter = downloads.makeAsyncIterator()
				let download = await iter.next()!

				let failure = try await download.failure()
				#expect(failure == nil)
			}
		}

		@Test("download.delete removes the artifact")
		func downloadDelete() async throws {
			try await withPage { page in
				try await page.setContent("""
					<a id="dl" href="data:text/plain,delete%20me" download="del.txt">Download</a>
					""")

				let (downloads, continuation) = AsyncStream<Download>.makeStream()
				page.onDownload { download in continuation.yield(download) }

				try await page.locator("#dl").click()

				var iter = downloads.makeAsyncIterator()
				let download = await iter.next()!

				// Get path before delete
				let path = try await download.path()
				#expect(FileManager.default.fileExists(atPath: path))

				// Delete and verify it's gone
				try await download.delete()
				#expect(!FileManager.default.fileExists(atPath: path))
			}
		}
	}
}
