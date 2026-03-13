import Testing
import Foundation
@testable import Playwright
import Synchronization

extension PlaywrightTests {
	@Suite(.serialized)
	struct CrossBrowserTests {
		@Test("Launch, newPage, and close works", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func fullLifecycle(browserName: String) async throws {
			let playwright = try await Playwright.launch()
			let browser = try await browserType(named: browserName, from: playwright).launch()
			#expect(browser.isConnected)
			#expect(!browser.version.isEmpty)

			let page = try await browser.newPage()
			#expect(page.url == "about:blank")
			#expect(!page.isClosed)

			try await page.close()
			#expect(page.isClosed)

			try await browser.close()
			#expect(!browser.isConnected)

			await playwright.close()
		}

		@Test("Multiple pages across contexts", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func multiplePagesAcrossContexts(browserName: String) async throws {
			try await withBrowser(browser: browserName) { browser in
				let context1 = try await browser.newContext()
				let context2 = try await browser.newContext()

				_ = try await context1.newPage()
				_ = try await context2.newPage()

				#expect(context1.pages.count == 1)
				#expect(context2.pages.count == 1)
				#expect(browser.contexts.count == 2)
			}
		}

		@Test("Navigation and title work across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func navigationCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				let response = try await page.goto("https://example.com")
				#expect(response?.ok == true)
				#expect(page.url.contains("example.com"))

				let title = try await page.title()
				#expect(title == "Example Domain")
			}
		}

		@Test("Locator actions work across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func locatorActionsCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("""
						<button onclick="document.title = 'clicked'">Click me</button>
						<input type="text" />
					""")

				try await page.locator("button").click()
				#expect(try await page.title() == "clicked")

				try await page.locator("input").fill("hello")
				#expect(try await page.locator("input").inputValue() == "hello")
			}
		}

		@Test("Evaluate and screenshot work across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func evaluateScreenshotCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("<h1>Test</h1>")

				let result = try await page.evaluate("1 + 1")
				#expect(result as? Int == 2)

				let screenshot = try await page.screenshot()
				#expect(!screenshot.isEmpty)
				// PNG magic bytes
				#expect(screenshot[0] == 0x89)
				#expect(screenshot[1] == 0x50) // 'P'
				#expect(screenshot[2] == 0x4E) // 'N'
				#expect(screenshot[3] == 0x47) // 'G'
			}
		}

		// MARK: - v0.4 Cross-Browser Tests

		@Test("querySelector and querySelectorAll work across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func querySelectorCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("<ul><li>A</li><li>B</li><li>C</li></ul>")

				let item = try await page.querySelector("li")
				#expect(item != nil)

				let items = try await page.querySelectorAll("li")
				#expect(items.count == 3)
			}
		}

		@Test("ElementHandle query methods work across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func elementHandleCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("""
					<div class="card"><h2>Title</h2><a href="/link">Link</a></div>
					""")

				let card = try await page.querySelector(".card")!
				let h2 = try await card.querySelector("h2")!
				#expect(try await h2.innerText() == "Title")

				let link = try await card.querySelector("a")!
				#expect(try await link.getAttribute("href") == "/link")
			}
		}

		@Test("Keyboard and mouse work across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func keyboardMouseCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("""
					<input type='text' />
					<button onclick="document.title = 'clicked'">Click me</button>
					""")

				// Keyboard: type into input
				try await page.locator("input").focus()
				try await page.keyboard.type("hello")
				#expect(try await page.locator("input").inputValue() == "hello")

				// Mouse: click the button by coordinates
				let box: [String: Any] = try await page.evaluate("""
					(() => { const r = document.querySelector('button').getBoundingClientRect(); return { x: r.x + r.width/2, y: r.y + r.height/2 }; })()
					""")
				let x = box["x"] as! Double
				let y = box["y"] as! Double
				try await page.mouse.click(x: x, y: y)
				#expect(try await page.title() == "clicked")
			}
		}

		@Test("Dialog handling works across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func dialogCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				let dialogReceived = Mutex(false)

				await page.onDialog { dialog in
					dialogReceived.withLock { $0 = true }
					try? await dialog.accept()
				}

				_ = try await page.evaluate("window.alert('test')" as String) as Any?
				#expect(dialogReceived.withLock { $0 })
			}
		}

		@Test("Download works across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func downloadCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("""
					<a id="dl" href="data:text/plain,cross-browser" download="test.txt">Download</a>
					""")

				let (downloads, continuation) = AsyncStream<Download>.makeStream()
				page.onDownload { download in continuation.yield(download) }

				try await page.locator("#dl").click()

				var iter = downloads.makeAsyncIterator()
				let download = await iter.next()!
				#expect(download.suggestedFilename == "test.txt")

				let path = try await download.path()
				#expect(!path.isEmpty)
			}
		}

		@Test("Persistent context works across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func persistentContextCrossBrowser(browserName: String) async throws {
			try await withPersistentContext(browser: browserName) { context in
				let page: Page
				if let existing = context.pages.first { page = existing }
				else { page = try await context.newPage() }

				try await page.setContent("<h1>Persistent</h1>")
				let text = try await page.locator("h1").textContent()
				#expect(text == "Persistent")

				let result: Int = try await page.evaluate("2 + 2")
				#expect(result == 4)
			}
		}

		@Test("Locator evaluate works across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func locatorEvaluateCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("<div id='test'>content</div>")
				let result = try await page.locator("#test").evaluate("el => el.id")
				#expect(result as? String == "test")
			}
		}

		@Test("Route interception works across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func routeCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.route("**/mock") { route in
					try await route.fulfill(status: 200, body: "mocked")
				}

				try await page.route("**/base") { route in
					try await route.fulfill(status: 200, body: "<html></html>")
				}

				try await page.goto("https://test.local/base")
				let result: String = try await page.evaluate("fetch('/mock').then(r => r.text())")
				#expect(result == "mocked")
			}
		}

		// MARK: - Quick-Win Properties

		@Test("page.viewportSize works across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func viewportSizeCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				let size = page.viewportSize
				#expect(size != nil)
				#expect(size?.width == 1280)
				#expect(size?.height == 720)
			}
		}

		@Test("frame tree works across browsers", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func frameTreeCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				#expect(page.frames.count == 1)
				#expect(page.mainFrame.parentFrame == nil)
				#expect(page.mainFrame.isDetached == false)
			}
		}

		@Test("browser.browserType.name matches the launched browser across engines", .serialized, arguments: ["chromium", "firefox", "webkit"])
		func browserTypeCrossBrowser(browserName: String) async throws {
			try await withBrowser(browser: browserName) { browser in
				#expect(browser.browserType.name == browserName)
			}
		}
	}
}
