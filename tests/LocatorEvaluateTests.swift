import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct LocatorEvaluateTests {
		@Test("locator.evaluate returns tag name")
		func evaluateTagName() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Hello</h1>")
				let result = try await page.locator("h1").evaluate("el => el.tagName")
				#expect(result as? String == "H1")
			}
		}

		@Test("locator.evaluate passes argument")
		func evaluateWithArg() async throws {
			try await withPage { page in
				try await page.setContent("<span>World</span>")
				let result = try await page.locator("span").evaluate("(el, x) => el.textContent + x", arg: "!")
				#expect(result as? String == "World!")
			}
		}

		@Test("locator.evaluateAll returns count of matching elements")
		func evaluateAllCount() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li><li>C</li></ul>")
				let result = try await page.locator("li").evaluateAll("els => els.length")
				#expect(result as? Int == 3)
			}
		}

		@Test("locator.evaluateAll passes argument to all elements")
		func evaluateAllWithArg() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li></ul>")
				let result = try await page.locator("li").evaluateAll("(els, x) => els.map(el => el.textContent + x)", arg: "!")
				let arr = result as? [Any]
				#expect(arr?.count == 2)
				#expect((arr?.first as? String) == "A!")
			}
		}

		@Test("locator.evaluate on non-existent element throws")
		func evaluateNonExistent() async throws {
			try await withPage { page in
				try await page.setContent("<div></div>")
				await #expect(throws: PlaywrightError.self) {
					_ = try await page.locator(".missing").evaluate("el => el.tagName", timeout: .seconds(1))
				}
			}
		}

		// MARK: - Typed evaluate

		@Test("typed locator.evaluate returns String")
		func typedEvaluateString() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Hello</h1>")
				let tagName: String = try await page.locator("h1").evaluate("el => el.tagName")
				#expect(tagName == "H1")
			}
		}

		@Test("typed locator.evaluate returns Int")
		func typedEvaluateInt() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li></ul>")
				let count: Int = try await page.locator("ul").evaluate("el => el.children.length")
				#expect(count == 2)
			}
		}

		@Test("typed locator.evaluate returns Bool")
		func typedEvaluateBool() async throws {
			try await withPage { page in
				try await page.setContent("<input type='checkbox' checked>")
				let checked: Bool = try await page.locator("input").evaluate("el => el.checked")
				#expect(checked == true)
			}
		}

		@Test("typed locator.evaluate throws on type mismatch")
		func typedEvaluateMismatch() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Hello</h1>")
				await #expect {
					let _: Int = try await page.locator("h1").evaluate("el => el.tagName")
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}

		@Test("typed locator.evaluateAll returns Int")
		func typedEvaluateAllInt() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li><li>C</li></ul>")
				let count: Int = try await page.locator("li").evaluateAll("els => els.length")
				#expect(count == 3)
			}
		}

		@Test("typed locator.evaluateAll returns String")
		func typedEvaluateAllString() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li></ul>")
				let joined: String = try await page.locator("li").evaluateAll("els => els.map(e => e.textContent).join(',')")
				#expect(joined == "A,B")
			}
		}

		@Test("typed locator.evaluateAll throws on type mismatch")
		func typedEvaluateAllMismatch() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li></ul>")
				await #expect {
					let _: Bool = try await page.locator("li").evaluateAll("els => els.length")
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}
	}
}
