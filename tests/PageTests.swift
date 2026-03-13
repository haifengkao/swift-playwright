import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct PageTests {
		@Test("context.newPage() returns a Page")
		func newPage() async throws {
			try await withContext { context in
				let page = try await context.newPage()
				#expect(!page.isClosed)
			}
		}

		@Test("New page appears in context.pages")
		func pageInContextPages() async throws {
			try await withContext { context in
				let page = try await context.newPage()
				#expect(context.pages.count == 1)
				#expect(context.pages.first === page)
			}
		}

		@Test("page.url is about:blank for a fresh page")
		func freshPageUrl() async throws {
			try await withPage { page in
				#expect(page.url == "about:blank")
			}
		}

		@Test("page.close() marks page closed and removes from context")
		func closeCleansUp() async throws {
			try await withContext { context in
				let page = try await context.newPage()
				#expect(context.pages.count == 1)

				try await page.close()
				#expect(page.isClosed)
				#expect(context.pages.isEmpty)
			}
		}

		@Test("Multiple pages can coexist in one context")
		func multiplePages() async throws {
			try await withContext { context in
				_ = try await context.newPage()
				_ = try await context.newPage()
				#expect(context.pages.count == 2)
			}
		}

		@Test("page.context references the owning context")
		func pageContext() async throws {
			try await withContext { context in
				let page = try await context.newPage()
				#expect(page.context === context)
			}
		}

		// MARK: - Viewport Size

		@Test("page.viewportSize returns default 1280x720 when no viewport set")
		func defaultViewport() async throws {
			try await withPage { page in
				let size = page.viewportSize
				#expect(size != nil)
				#expect(size?.width == 1280)
				#expect(size?.height == 720)
			}
		}

		@Test("page.viewportSize returns custom size when context sets viewport")
		func customViewport() async throws {
			try await withBrowser { browser in
				let context = try await browser.newContext(
					viewport: ViewportSize(width: 800, height: 600)
				)
				let page = try await context.newPage()

				let size = page.viewportSize
				#expect(size?.width == 800)
				#expect(size?.height == 600)

				try await context.close()
			}
		}

		@Test("page.viewportSize is nil when viewport is explicitly disabled")
		func nilViewport() async throws {
			try await withBrowser { browser in
				let context = try await browser.newContext(noViewport: true)
				let page = try await context.newPage()

				#expect(page.viewportSize == nil)

				try await context.close()
			}
		}

		// MARK: - Frames

		@Test("page.frames returns only the main frame on a blank page")
		func framesBlankPage() async throws {
			try await withPage { page in
				let frames = page.frames
				#expect(frames.count == 1)
				#expect(frames.first === page.mainFrame)
			}
		}

		@Test("page.frames includes iframes after navigation")
		func framesWithIframes() async throws {
			try await withPage { page in
				try await page.setContent("""
					<iframe src="about:blank" name="frame1"></iframe>
					<iframe src="about:blank" name="frame2"></iframe>
					""")

				// Wait briefly for frame-attached events to propagate
				try await page.waitForTimeout(.milliseconds(200))

				let frames = page.frames
				#expect(frames.count == 3) // main + 2 iframes
			}
		}

		@Test("page.frames always starts with mainFrame")
		func framesMainFrameFirst() async throws {
			try await withPage { page in
				#expect(page.frames.first === page.mainFrame)
			}
		}

		@Test("mainFrame.parentFrame is nil")
		func mainFrameHasNoParent() async throws {
			try await withPage { page in
				#expect(page.mainFrame.parentFrame == nil)
			}
		}

		@Test("iframe.parentFrame points to main frame")
		func iframeParentFrame() async throws {
			try await withPage { page in
				try await page.setContent("""
					<iframe src="about:blank" name="child"></iframe>
					""")

				try await page.waitForTimeout(.milliseconds(200))

				let childFrame = page.frames.first(where: { $0 !== page.mainFrame })
				#expect(childFrame != nil)
				#expect(childFrame?.parentFrame === page.mainFrame)
			}
		}

		@Test("mainFrame.childFrames contains iframes")
		func mainFrameChildFrames() async throws {
			try await withPage { page in
				try await page.setContent("""
					<iframe src="about:blank" name="child1"></iframe>
					<iframe src="about:blank" name="child2"></iframe>
					""")

				try await page.waitForTimeout(.milliseconds(200))

				#expect(page.mainFrame.childFrames.count == 2)
			}
		}

		@Test("mainFrame.isDetached is false for an attached frame")
		func mainFrameIsNotDetached() async throws {
			try await withPage { page in
				#expect(page.mainFrame.isDetached == false)
			}
		}

		@Test("frame.page returns the owning page")
		func framePageReference() async throws {
			try await withPage { page in
				#expect(page.mainFrame.page === page)
			}
		}
	}
}
