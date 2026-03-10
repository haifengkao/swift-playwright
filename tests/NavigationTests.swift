import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct NavigationTests {
		@Test("page.goto navigates and returns a Response")
		func gotoReturnsResponse() async throws {
			try await withPage { page in
				let response = try #require(try await page.goto("https://example.com"))
				#expect(response.status == 200)
				#expect(response.ok == true)
				#expect(response.url.contains("example.com"))
			}
		}

		@Test("page.url reflects the navigated URL")
		func urlUpdatedAfterGoto() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				#expect(page.url.contains("example.com"))
			}
		}

		@Test("Response has correct headers")
		func responseHeaders() async throws {
			try await withPage { page in
				let response = try #require(try await page.goto("https://example.com"))
				#expect(response.headers["content-type"]?.contains("text/html") == true)
			}
		}

		@Test("Response request is accessible")
		func responseRequest() async throws {
			try await withPage { page in
				let response = try #require(try await page.goto("https://example.com"))
				#expect(response.request?.url.contains("example.com") == true)
				#expect(response.request?.method == "GET")
			}
		}

		@Test("page.title returns the page title")
		func pageTitle() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				let title = try await page.title()
				#expect(title == "Example Domain")
			}
		}

		@Test("page.reload reloads the page")
		func pageReload() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				let response = try #require(try await page.reload())
				#expect(response.ok == true)
			}
		}

		@Test("page.goBack and goForward navigate history")
		func goBackForward() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				try await page.goto("https://www.iana.org/")
				#expect(page.url.contains("iana.org"))

				_ = try await page.goBack()
				#expect(page.url.contains("example.com"))

				_ = try await page.goForward()
				#expect(page.url.contains("iana.org"))
			}
		}

		@Test("page.content returns HTML content")
		func pageContent() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				let content = try await page.content()
				#expect(content.contains("<html"))
				#expect(content.contains("Example Domain"))
			}
		}

		@Test("page.setContent sets the page HTML")
		func pageSetContent() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Hello World</h1>")
				let content = try await page.content()
				#expect(content.contains("Hello World"))
			}
		}

		/// NOTE: This only verifies each WaitUntilState is accepted by the server.
		/// Verifying the readiness state was actually honored requires a page with
		/// delayed resources (needs page.route() or a test server).
		@Test("page.goto accepts all waitUntil states", arguments: [
			WaitUntilState.load, .domcontentloaded, .networkidle, .commit,
		])
		func gotoWithWaitUntil(state: WaitUntilState) async throws {
			try await withPage { page in
				let response = try await page.goto("https://example.com", waitUntil: state)
				#expect(response?.ok == true)
			}
		}

		@Test("Response.json() parses a JSON fragment (bare number)")
		func responseJsonFragment() async throws {
			try await withPage { page in
				try await page.setContent("<div></div>")
				let blobUrl: String = try await page.evaluate("""
						(() => {
							const blob = new Blob(['42'], { type: 'application/json' });
							return URL.createObjectURL(blob);
						})()
					""")

				let response = try #require(try await page.goto(blobUrl))
				let json = try await response.json()
				#expect(json as? Int == 42)
			}
		}

		@Test("Response.body() returns raw bytes")
		func responseBody() async throws {
			try await withPage { page in
				try await page.setContent("<div></div>")
				let blobUrl: String = try await page.evaluate("""
						(() => {
							const blob = new Blob(['hello bytes'], { type: 'text/plain' });
							return URL.createObjectURL(blob);
						})()
					""")

				let response = try #require(try await page.goto(blobUrl))
				let body = try await response.body()
				#expect(body == Data("hello bytes".utf8))
			}
		}

		@Test("Response.text() returns body as UTF-8 string")
		func responseText() async throws {
			try await withPage { page in
				try await page.setContent("<div></div>")
				let blobUrl: String = try await page.evaluate("""
						(() => {
							const blob = new Blob(['hello world'], { type: 'text/plain' });
							return URL.createObjectURL(blob);
						})()
					""")

				let response = try #require(try await page.goto(blobUrl))
				let text = try await response.text()
				#expect(text == "hello world")
			}
		}

		@Test("Response.json() parses nested objects")
		func responseJsonNested() async throws {
			try await withPage { page in
				try await page.setContent("<div></div>")
				let blobUrl: String = try await page.evaluate("""
						(() => {
							const blob = new Blob(['{"name":"test","nested":{"value":42},"items":[1,2,3]}'], { type: 'application/json' });
							return URL.createObjectURL(blob);
						})()
					""")

				let response = try #require(try await page.goto(blobUrl))
				let json = try #require(try await response.json() as? [String: Any])
				#expect(json["name"] as? String == "test")
				let nested = json["nested"] as? [String: Any]
				#expect(nested?["value"] as? Int == 42)
				let items = json["items"] as? [Any]
				#expect(items?.count == 3)
			}
		}

		@Test("page.goBack returns nil when no history")
		func goBackNoHistory() async throws {
			try await withPage { page in
				let response = try await page.goBack()
				#expect(response == nil)
			}
		}

		@Test("page.goForward returns nil when no forward history")
		func goForwardNoHistory() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				let response = try await page.goForward()
				#expect(response == nil)
			}
		}

		@Test("page.reload accepts waitUntil option")
		func reloadWithWaitUntil() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				let response = try await page.reload(waitUntil: .domcontentloaded)
				#expect(response?.ok == true)
			}
		}

		// TODO: Once page.route() is available, add a test for Response.text() with non-UTF-8 bytes
		// to verify lossy decoding (U+FFFD replacement) instead of collapsing to empty string.

		// MARK: - Navigation error cases

		@Test("page.goto with unreachable URL throws navigationFailed")
		func gotoUnreachable() async throws {
			try await withPage { page in
				await #expect {
					try await page.goto("https://localhost:1", timeout: .seconds(5))
				} throws: { error in
					guard case PlaywrightError.navigationFailed = error else { return false }
					return true
				}
			}
		}

		@Test("page.goto with referer sets the referer header")
		func gotoWithReferer() async throws {
			try await withPage { page in
				try await page.goto("https://example.com", referer: "https://custom-referer.example/")
				let referrer: String = try await page.evaluate("document.referrer")
				#expect(referrer == "https://custom-referer.example/")
			}
		}

		@Test("page.goto to about:blank returns nil response")
		func gotoAboutBlank() async throws {
			try await withPage { page in
				let response = try await page.goto("about:blank")
				#expect(response == nil)
			}
		}

		@Test("page.setContent with waitUntil option")
		func setContentWithWaitUntil() async throws {
			try await withPage { page in
				try await page.setContent("<h1>Hello</h1>", waitUntil: .load)
				let content = try await page.content()
				#expect(content.contains("Hello"))
			}
		}

		// MARK: - Request properties

		@Test("Request has resourceType and isNavigationRequest")
		func requestProperties() async throws {
			try await withPage { page in
				let response = try #require(try await page.goto("https://example.com"))
				let request = try #require(response.request)
				#expect(request.resourceType == "document")
				#expect(request.isNavigationRequest)
				#expect(!request.headers.isEmpty)
			}
		}

		@Test("Request has nil postData for GET requests")
		func requestGetPostData() async throws {
			try await withPage { page in
				let response = try #require(try await page.goto("https://example.com"))
				let request = try #require(response.request)
				#expect(request.postData == nil)
			}
		}

		// TODO: Add test for Request.postData once page.route() is available —
		// need network interception to capture a POST request and inspect its body.

		// MARK: - Response body edge cases

		@Test("Response.body() caches result — second call reuses stored data")
		func responseBodyCaching() async throws {
			try await withPage { page in
				let response = try #require(try await page.goto("https://example.com"))
				// First call fetches from server and caches
				let body1 = try await response.body()

				// Navigate away so the original response is no longer available on the server
				_ = try await page.goto("about:blank")

				// Second call must return cached data — a refetch would fail
				let body2 = try await response.body()
				#expect(body1 == body2)
				#expect(!body1.isEmpty)
			}
		}
	}
}
