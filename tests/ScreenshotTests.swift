import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct ScreenshotTests {
		@Test("page.screenshot returns non-empty PNG data")
		func screenshotPNG() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				let data = try await page.screenshot()
				#expect(!data.isEmpty)
				// PNG magic bytes
				#expect(data[0] == 0x89)
				#expect(data[1] == 0x50) // 'P'
				#expect(data[2] == 0x4E) // 'N'
				#expect(data[3] == 0x47) // 'G'
			}
		}

		@Test("page.screenshot with JPEG type")
		func screenshotJPEG() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				let data = try await page.screenshot(type: .jpeg, quality: 80)
				#expect(!data.isEmpty)
				// JPEG magic bytes
				#expect(data[0] == 0xFF)
				#expect(data[1] == 0xD8)
			}
		}

		@Test("page.screenshot with fullPage option")
		func screenshotFullPage() async throws {
			try await withPage { page in
				try await page.setContent("<div style='height: 3000px'>Tall page</div>")
				let data = try await page.screenshot(fullPage: true)
				#expect(!data.isEmpty)
			}
		}

		@Test("locator.screenshot captures element screenshot")
		func locatorScreenshot() async throws {
			try await withPage { page in
				try await page.setContent("<div id='target' style='width:100px;height:100px;background:red'>Box</div>")
				let data = try await page.locator("#target").screenshot()
				#expect(!data.isEmpty)
				// Should be PNG by default
				#expect(data[0] == 0x89)
			}
		}

		// MARK: - Format inference

		@Test("screenshotParams infers format from path extension", arguments: [
			("shot.png", "png"),
			("shot.jpg", "jpeg"),
			("shot.jpeg", "jpeg"),
			("shot.JPG", "jpeg"),
		])
		func infersFormatFromPath(path: String, expectedType: String) throws {
			let params = try screenshotParams(path: path)
			#expect(params["type"] as? String == expectedType)
		}

		@Test("screenshotParams defaults to PNG with no path or type")
		func defaultsPNGNoPathNoType() throws {
			let params = try screenshotParams()
			#expect(params["type"] as? String == "png")
		}

		@Test("screenshotParams respects explicit type over path extension")
		func explicitTypeOverridesPath() throws {
			let params = try screenshotParams(type: .png, path: "shot.jpg")
			#expect(params["type"] as? String == "png")
		}

		@Test("screenshotParams throws invalidArgument on unsupported extension")
		func throwsOnUnsupportedExtension() throws {
			#expect {
				try screenshotParams(path: "shot.bmp")
			} throws: { error in
				guard case PlaywrightError.invalidArgument = error else { return false }
				return true
			}
		}

		@Test("page.screenshot with .jpg path produces JPEG bytes")
		func screenshotJPEGFromPath() async throws {
			try await withPage { page in
				try await page.setContent("<h1>JPEG test</h1>")
				let path = NSTemporaryDirectory() + "playwright-test-\(UUID()).jpg"
				defer { try? FileManager.default.removeItem(atPath: path) }

				let data = try await page.screenshot(path: path)

				// JPEG magic bytes
				#expect(data[0] == 0xFF)
				#expect(data[1] == 0xD8)

				// File was written
				let saved = try Data(contentsOf: URL(fileURLWithPath: path))
				#expect(saved == data)
			}
		}

		@Test("page.screenshot creates parent directories for path")
		func screenshotCreatesDirectories() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Dir test</h1>")
				let root = NSTemporaryDirectory() + "playwright-test-\(UUID())"
				let path = root + "/nested/dir/shot.png"
				defer { try? FileManager.default.removeItem(atPath: root) }

				let data = try await page.screenshot(path: path)
				let saved = try Data(contentsOf: URL(fileURLWithPath: path))
				#expect(saved == data)
			}
		}

		// MARK: - Additional screenshot options

		@Test("page.screenshot with omitBackground produces PNG with transparency support")
		func screenshotOmitBackground() async throws {
			try await withPage { page in
				try await page.setContent("<div style='background:transparent'>Transparent</div>")
				let data = try await page.screenshot(omitBackground: true)
				#expect(!data.isEmpty)
				// Should be valid PNG
				#expect(data[0] == 0x89)
				#expect(data[1] == 0x50)
			}
		}

		@Test("locator.screenshot with path saves to file")
		func locatorScreenshotSavesToFile() async throws {
			try await withPage { page in
				try await page.setContent("<div id='target' style='width:100px;height:100px;background:green'>Box</div>")
				let path = NSTemporaryDirectory() + "playwright-locator-\(UUID()).png"
				defer { try? FileManager.default.removeItem(atPath: path) }

				let data = try await page.locator("#target").screenshot(path: path)
				#expect(!data.isEmpty)

				let saved = try Data(contentsOf: URL(fileURLWithPath: path))
				#expect(saved == data)
			}
		}

		@Test("locator.screenshot on nonexistent element throws elementNotFound")
		func locatorScreenshotMissing() async throws {
			try await withPage { page in
				try await page.setContent("<div>No target</div>")
				await #expect {
					try await page.locator(".nonexistent").screenshot(timeout: .seconds(2))
				} throws: { error in
					guard case PlaywrightError.elementNotFound = error else { return false }
					return true
				}
			}
		}
	}
}
