import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct QuerySelectorTests {
		@Test("querySelector returns ElementHandle for existing element")
		func querySelectorFindsElement() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Hello</h1>")
				let element = try await page.querySelector("h1")
				#expect(element != nil)
			}
		}

		@Test("querySelector returns nil for non-existent element")
		func querySelectorReturnsNil() async throws {
			try await withPage { page in
				try await page.setContent("<div>Content</div>")
				let element = try await page.querySelector(".nonexistent")
				#expect(element == nil)
			}
		}

		@Test("querySelectorAll returns correct number of elements")
		func querySelectorAllCount() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li><li>C</li></ul>")
				let elements = try await page.querySelectorAll("li")
				#expect(elements.count == 3)
			}
		}

		@Test("querySelectorAll returns empty array for no matches")
		func querySelectorAllEmpty() async throws {
			try await withPage { page in
				try await page.setContent("<div>Content</div>")
				let elements = try await page.querySelectorAll(".nonexistent")
				#expect(elements.isEmpty)
			}
		}

		@Test("waitForSelector returns ElementHandle for present element")
		func waitForSelectorPresent() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Title</h1>")
				let element = try #require(await page.waitForSelector("h1"))
				let text = try await element.textContent()
				#expect(text == "Title")
			}
		}

		@Test("waitForSelector with state visible waits for visibility")
		func waitForSelectorVisible() async throws {
			try await withPage { page in
				// Element starts hidden; script reveals it after 300ms
				try await page.setContent("""
					<div id='target' style='display:none'>Now visible</div>
					<script>setTimeout(() => document.getElementById('target').style.display = '', 300)</script>
					""")
				let start = ContinuousClock.now
				let element = try #require(await page.waitForSelector("#target", state: .visible))
				let elapsed = ContinuousClock.now - start
				#expect(elapsed >= .milliseconds(200), "should have waited for the element to become visible, but returned in \(elapsed)")
				let text = try await element.innerText()
				#expect(text == "Now visible")
			}
		}

		@Test("waitForSelector throws on timeout for missing element")
		func waitForSelectorTimeout() async throws {
			try await withPage { page in
				try await page.setContent("<div>Content</div>")
				await #expect {
					_ = try await page.waitForSelector(".nonexistent", timeout: .seconds(1))
				} throws: { error in
					error is PlaywrightError
				}
			}
		}

		@Test("waitForTimeout waits approximately the given duration")
		func waitForTimeoutDuration() async throws {
			try await withPage { page in
				let start = ContinuousClock.now
				try await page.waitForTimeout(.milliseconds(200))
				let elapsed = ContinuousClock.now - start
				#expect(elapsed >= .milliseconds(150))
			}
		}

		@Test("waitForSelector succeeds with nil for absent element states", arguments: [
			WaitForSelectorState.hidden,
			WaitForSelectorState.detached,
		])
		func waitForSelectorAbsentStates(state: WaitForSelectorState) async throws {
			try await withPage { page in
				try await page.setContent("<div>No target here</div>")
				let element = try await page.waitForSelector("#target", state: state)
				#expect(element == nil)
			}
		}

	}
}
