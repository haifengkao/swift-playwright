import Testing
import Foundation
@testable import Playwright
@testable import PlaywrightTesting

extension PlaywrightTests {
	@Suite struct LocatorAssertionTests {
		// MARK: - State Assertions

		@Test("toBeVisible passes for visible element")
		func toBeVisible() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Hello</h1>")
				try await expect(page.locator("h1")).toBeVisible()
			}
		}

		@Test("toBeVisible with negation passes for hidden element")
		func notToBeVisible() async throws {
			try await withPage { page in
				try await page.setContent("<h1 style='display:none'>Hidden</h1>")
				try await expect(page.locator("h1")).not.toBeVisible()
			}
		}

		@Test("toBeHidden passes for hidden element")
		func toBeHidden() async throws {
			try await withPage { page in
				try await page.setContent("<h1 style='display:none'>Hidden</h1>")
				try await expect(page.locator("h1")).toBeHidden()
			}
		}

		@Test("toBeEnabled passes for enabled input")
		func toBeEnabled() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' />")
				try await expect(page.locator("input")).toBeEnabled()
			}
		}

		@Test("toBeDisabled passes for disabled input")
		func toBeDisabled() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' disabled />")
				try await expect(page.locator("input")).toBeDisabled()
			}
		}

		@Test("toBeEditable passes for editable input")
		func toBeEditable() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' />")
				try await expect(page.locator("input")).toBeEditable()
			}
		}

		@Test("toBeChecked passes for checked checkbox")
		func toBeChecked() async throws {
			try await withPage { page in
				try await page.setContent("<input type='checkbox' checked />")
				try await expect(page.locator("input")).toBeChecked()
			}
		}

		@Test("toBeFocused passes for focused element")
		func toBeFocused() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' id='inp' />")
				try await page.locator("#inp").focus()
				try await expect(page.locator("#inp")).toBeFocused()
			}
		}

		@Test("toBeEmpty passes for empty input")
		func toBeEmpty() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' />")
				try await expect(page.locator("input")).toBeEmpty()
			}
		}

		@Test("toBeAttached passes for attached element")
		func toBeAttached() async throws {
			try await withPage { page in
				try await page.setContent("<div id='test'>content</div>")
				try await expect(page.locator("#test")).toBeAttached()
			}
		}

		@Test("toBeInViewport passes for element in viewport")
		func toBeInViewport() async throws {
			try await withPage { page in
				try await page.setContent("<div>visible</div>")
				try await expect(page.locator("div")).toBeInViewport()
			}
		}

		@Test("auto-retry: element becomes visible after delay, assertion passes")
		func autoRetry() async throws {
			try await withPage { page in
				try await page.setContent("""
					<div id="target" style="display:none">content</div>
					<script>
						setTimeout(() => {
							document.getElementById('target').style.display = 'block';
						}, 500);
					</script>
				""")
				try await expect(page.locator("#target")).toBeVisible(timeout: .seconds(5))
			}
		}

		@Test("state assertions across browsers", arguments: ["chromium", "firefox", "webkit"])
		func crossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("<h1>Hello</h1><h2 style='display:none'>Hidden</h2>")
				try await expect(page.locator("h1")).toBeVisible()
				try await expect(page.locator("h2")).toBeHidden()
			}
		}

		// MARK: - Text Assertions

		@Test("toHaveText passes for matching text")
		func toHaveText() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Example Domain</h1>")
				try await expect(page.locator("h1")).toHaveText("Example Domain")
			}
		}

		@Test("toContainText passes for substring")
		func toContainText() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Example Domain</h1>")
				try await expect(page.locator("h1")).toContainText("Example")
			}
		}

		@Test("toHaveAttribute passes for matching attribute")
		func toHaveAttribute() async throws {
			try await withPage { page in
				try await page.setContent("<a href='https://example.com'>Link</a>")
				try await expect(page.locator("a")).toHaveAttribute("href", "https://example.com")
			}
		}

		@Test("toHaveValue passes for input value")
		func toHaveValue() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' value='hello' />")
				try await expect(page.locator("input")).toHaveValue("hello")
			}
		}

		@Test("toHaveClass passes for element with class")
		func toHaveClass() async throws {
			try await withPage { page in
				try await page.setContent("<div class='active main'>content</div>")
				try await expect(page.locator("div")).toHaveClass("active main")
			}
		}

		@Test("toHaveId passes for element with id")
		func toHaveId() async throws {
			try await withPage { page in
				try await page.setContent("<h1 id='main-heading'>Title</h1>")
				try await expect(page.locator("h1")).toHaveId("main-heading")
			}
		}

		@Test("toHaveCount passes for matching count")
		func toHaveCount() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li><li>C</li></ul>")
				try await expect(page.locator("li")).toHaveCount(3)
			}
		}

		@Test("toHaveCSS passes for matching CSS property")
		func toHaveCSS() async throws {
			try await withPage { page in
				try await page.setContent("<div style='color: rgb(255, 0, 0)'>red</div>")
				try await expect(page.locator("div")).toHaveCSS("color", "rgb(255, 0, 0)")
			}
		}

		@Test("toHaveRole passes for element with role")
		func toHaveRole() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Title</h1>")
				try await expect(page.locator("h1")).toHaveRole(.heading)
			}
		}

		@Test("toHaveAccessibleName passes for element with accessible name")
		func toHaveAccessibleName() async throws {
			try await withPage { page in
				try await page.setContent("<button>Submit</button>")
				try await expect(page.locator("button")).toHaveAccessibleName("Submit")
			}
		}

		@Test("negation works for text assertions")
		func notToHaveText() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Hello</h1>")
				try await expect(page.locator("h1")).not.toHaveText("Wrong")
			}
		}

		@Test("text assertions across browsers", arguments: ["chromium", "firefox", "webkit"])
		func textCrossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("<h1>Example</h1>")
				try await expect(page.locator("h1")).toHaveText("Example")
				try await expect(page.locator("h1")).toContainText("Exam")
			}
		}
	}
}
