import Testing
import Foundation
import Synchronization
@testable import Playwright

extension PlaywrightTests {
	@Suite struct DialogTests {
		@Test("alert dialog is received with correct message")
		func alertDialog() async throws {
			try await withPage { page in
				let dialogReceived = Mutex(false)
				let dialogMessage = Mutex("")

				await page.onDialog { dialog in
					dialogMessage.withLock { $0 = dialog.message }
					dialogReceived.withLock { $0 = true }
					try? await dialog.accept()
				}

				_ = try await page.evaluate("window.alert('Hello!')" as String) as Any?
				#expect(dialogReceived.withLock { $0 })
				#expect(dialogMessage.withLock { $0 } == "Hello!")
			}
		}

		@Test("dialog.dialogType is .alert for window.alert()")
		func dialogTypeAlert() async throws {
			try await withPage { page in
				let dialogType = Mutex<DialogType?>(nil)

				await page.onDialog { dialog in
					dialogType.withLock { $0 = dialog.dialogType }
					try? await dialog.accept()
				}

				_ = try await page.evaluate("window.alert('test')" as String) as Any?
				#expect(dialogType.withLock { $0 } == .alert)
			}
		}

		@Test("confirm dialog returns false when dismissed")
		func confirmDismiss() async throws {
			try await withPage { page in
				await page.onDialog { dialog in
					try? await dialog.dismiss()
				}

				let result: Bool = try await page.evaluate("window.confirm('Are you sure?')")
				#expect(result == false)
			}
		}

		@Test("confirm dialog returns true when accepted")
		func confirmAccept() async throws {
			try await withPage { page in
				await page.onDialog { dialog in
					try? await dialog.accept()
				}

				let result: Bool = try await page.evaluate("window.confirm('Are you sure?')")
				#expect(result == true)
			}
		}

		@Test("prompt dialog returns entered text")
		func promptAcceptWithText() async throws {
			try await withPage { page in
				await page.onDialog { dialog in
					try? await dialog.accept(promptText: "hello")
				}

				let result: String = try await page.evaluate("window.prompt('Enter text:')")
				#expect(result == "hello")
			}
		}

		@Test("dialog routes to the correct page in multi-page context")
		func dialogRoutesToCorrectPage() async throws {
			try await withContext { context in
				let pageA = try await context.newPage()
				let pageB = try await context.newPage()

				let handlerCalledOnA = Mutex(false)
				let handlerCalledOnB = Mutex(false)

				await pageA.onDialog { dialog in
					handlerCalledOnA.withLock { $0 = true }
					try? await dialog.accept()
				}
				await pageB.onDialog { dialog in
					handlerCalledOnB.withLock { $0 = true }
					try? await dialog.accept()
				}

				// Trigger alert on page B
				_ = try await pageB.evaluate("window.alert('from B')" as String) as Any?

				#expect(handlerCalledOnB.withLock { $0 }, "pageB's handler should have been called")
				#expect(!handlerCalledOnA.withLock { $0 }, "pageA's handler should NOT have been called")
			}
		}

		@Test("prompt dialog exposes defaultValue")
		func promptDefaultValue() async throws {
			try await withPage { page in
				let capturedDefault = Mutex("")

				await page.onDialog { dialog in
					capturedDefault.withLock { $0 = dialog.defaultValue }
					try? await dialog.accept(promptText: dialog.defaultValue)
				}

				let result: String = try await page.evaluate("window.prompt('Name?', 'Alice')")
				#expect(capturedDefault.withLock { $0 } == "Alice")
				#expect(result == "Alice")
			}
		}

		@Test("dialog with no listener is auto-dismissed", arguments: [
			("window.alert('Auto dismiss?'); 'ok'", "ok"),
			("String(window.confirm('Auto dismiss?'))", "false"),
		])
		func autoDismissal(expression: String, expected: String) async throws {
			try await withPage { page in
				// No dialog handler registered — should auto-dismiss without hanging
				let result: String = try await page.evaluate(expression)
				#expect(result == expected)
			}
		}
	}
}
