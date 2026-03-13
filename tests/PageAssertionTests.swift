import Testing
import Foundation
@testable import Playwright
@testable import PlaywrightTesting

extension PlaywrightTests {
	@Suite struct PageAssertionTests {
		@Test("toHaveTitle passes after navigation")
		func toHaveTitle() async throws {
			try await withPage { page in
				try await page.setContent("<title>Example Domain</title>")
				try await expect(page).toHaveTitle("Example Domain")
			}
		}

		@Test("toHaveURL passes after navigation")
		func toHaveURL() async throws {
			try await withPage { page in
				try await page.goto("data:text/html,<h1>test</h1>")
				try await expect(page).toHaveURL("data:text/html,<h1>test</h1>")
			}
		}

		@Test("not.toHaveTitle passes for non-matching title")
		func notToHaveTitle() async throws {
			try await withPage { page in
				try await page.setContent("<title>Actual Title</title>")
				try await expect(page).not.toHaveTitle("Wrong Title")
			}
		}

		@Test("not.toHaveURL passes for non-matching URL")
		func notToHaveURL() async throws {
			try await withPage { page in
				try await expect(page).not.toHaveURL("https://wrong.com")
			}
		}

		@Test("auto-retry: title changes after delay, assertion passes")
		func autoRetryTitle() async throws {
			try await withPage { page in
				try await page.setContent("""
					<title>Initial</title>
					<script>
						setTimeout(() => { document.title = 'Updated'; }, 500);
					</script>
				""")
				try await expect(page).toHaveTitle("Updated", timeout: .seconds(5))
			}
		}

		@Test("page assertions across browsers", arguments: ["chromium", "firefox", "webkit"])
		func crossBrowser(browserName: String) async throws {
			try await withPage(browser: browserName) { page in
				try await page.setContent("<title>Test Page</title>")
				try await expect(page).toHaveTitle("Test Page")
			}
		}
	}
}
