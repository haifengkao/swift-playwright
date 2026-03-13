import Testing
import Foundation
import Synchronization
@testable import Playwright

extension PlaywrightTests {
	@Suite struct ConsoleMessageTests {
		@Test("page.onConsole captures console.log with type .log")
		func captureLog() async throws {
			try await withPage { page in
				let messages = Mutex<[ConsoleMessage]>([])

				await page.onConsole { msg in
					messages.withLock { $0.append(msg) }
				}

				_ = try await page.evaluate("console.log('hello')" as String) as Any?
				try await page.waitForTimeout(.milliseconds(200))

				let captured = messages.withLock { $0 }
				#expect(captured.contains { $0.text == "hello" && $0.consoleType == .log })
			}
		}

		@Test("page.onConsole captures console.error with type .error")
		func captureError() async throws {
			try await withPage { page in
				let messages = Mutex<[ConsoleMessage]>([])

				await page.onConsole { msg in
					messages.withLock { $0.append(msg) }
				}

				_ = try await page.evaluate("console.error('fail')" as String) as Any?
				try await page.waitForTimeout(.milliseconds(200))

				let captured = messages.withLock { $0 }
				#expect(captured.contains { $0.text == "fail" && $0.consoleType == .error })
			}
		}

		@Test("page.onConsole captures console.warn with type .warning")
		func captureWarning() async throws {
			try await withPage { page in
				let messages = Mutex<[ConsoleMessage]>([])

				await page.onConsole { msg in
					messages.withLock { $0.append(msg) }
				}

				_ = try await page.evaluate("console.warn('warning')" as String) as Any?
				try await page.waitForTimeout(.milliseconds(200))

				let captured = messages.withLock { $0 }
				#expect(captured.contains { $0.text == "warning" && $0.consoleType == .warning })
			}
		}

		@Test("multiple console messages captured in order")
		func multipleMessages() async throws {
			try await withPage { page in
				let messages = Mutex<[String]>([])

				await page.onConsole { msg in
					messages.withLock { $0.append(msg.text) }
				}

				_ = try await page.evaluate("""
					console.log('first');
					console.log('second');
					console.log('third');
				""" as String) as Any?
				try await page.waitForTimeout(.milliseconds(200))

				let captured = messages.withLock { $0 }
				#expect(captured.contains("first"))
				#expect(captured.contains("second"))
				#expect(captured.contains("third"))
			}
		}

		@Test("ConsoleMessage.location has non-empty URL")
		func locationURL() async throws {
			try await withPage { page in
				let messages = Mutex<[ConsoleMessage]>([])

				await page.onConsole { msg in
					messages.withLock { $0.append(msg) }
				}

				_ = try await page.evaluate("console.log('from-page')" as String) as Any?
				try await page.waitForTimeout(.milliseconds(200))

				let captured = messages.withLock { $0 }
				let fromPage = captured.first { $0.text == "from-page" }
				#expect(fromPage != nil)
			}
		}

		@Test("context.onConsole captures console messages from pages")
		func contextConsole() async throws {
			try await withContext { context in
				let messages = Mutex<[ConsoleMessage]>([])

				await context.onConsole { msg in
					messages.withLock { $0.append(msg) }
				}

				let page = try await context.newPage()
				_ = try await page.evaluate("console.log('from-context')" as String) as Any?
				try await page.waitForTimeout(.milliseconds(200))

				let captured = messages.withLock { $0 }
				#expect(captured.contains { $0.text == "from-context" && $0.consoleType == .log })
			}
		}

		@Test("context.onConsole message includes page reference")
		func contextConsolePageReference() async throws {
			try await withContext { context in
				let messages = Mutex<[ConsoleMessage]>([])

				await context.onConsole { msg in
					messages.withLock { $0.append(msg) }
				}

				let page = try await context.newPage()
				_ = try await page.evaluate("console.log('with-page')" as String) as Any?
				try await page.waitForTimeout(.milliseconds(200))

				let captured = messages.withLock { $0 }
				let msg = captured.first { $0.text == "with-page" }
				#expect(msg?.page === page)
			}
		}

		@Test("context.onConsole and page.onConsole both fire")
		func contextAndPageConsole() async throws {
			try await withContext { context in
				let contextMessages = Mutex<[String]>([])
				let pageMessages = Mutex<[String]>([])

				await context.onConsole { msg in
					contextMessages.withLock { $0.append(msg.text) }
				}

				let page = try await context.newPage()
				await page.onConsole { msg in
					pageMessages.withLock { $0.append(msg.text) }
				}

				_ = try await page.evaluate("console.log('both')" as String) as Any?
				try await page.waitForTimeout(.milliseconds(200))

				let ctxCaptured = contextMessages.withLock { $0 }
				let pgCaptured = pageMessages.withLock { $0 }
				#expect(ctxCaptured.contains("both"))
				#expect(pgCaptured.contains("both"))
			}
		}

		@Test("context.onConsole captures from multiple pages")
		func contextConsoleMultiplePages() async throws {
			try await withContext { context in
				let messages = Mutex<[String]>([])

				await context.onConsole { msg in
					messages.withLock { $0.append(msg.text) }
				}

				let page1 = try await context.newPage()
				let page2 = try await context.newPage()

				_ = try await page1.evaluate("console.log('page-one')" as String) as Any?
				_ = try await page2.evaluate("console.log('page-two')" as String) as Any?
				try await page1.waitForTimeout(.milliseconds(200))

				let captured = messages.withLock { $0 }
				#expect(captured.contains("page-one"))
				#expect(captured.contains("page-two"))
			}
		}

		@Test("console messages captured across browsers", arguments: ["chromium", "firefox", "webkit"])
		func crossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				let messages = Mutex<[ConsoleMessage]>([])

				await page.onConsole { msg in
					messages.withLock { $0.append(msg) }
				}

				_ = try await page.evaluate("console.log('cross-browser')" as String) as Any?
				try await page.waitForTimeout(.milliseconds(200))

				let captured = messages.withLock { $0 }
				#expect(captured.contains { $0.text == "cross-browser" })
			}
		}
	}
}
