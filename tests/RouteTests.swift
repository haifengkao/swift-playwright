import Testing
import Foundation
@testable import Playwright
import Synchronization

extension PlaywrightTests {
	@Suite struct RouteTests {
		@Test("route.abort blocks matching requests")
		func routeAbort() async throws {
			try await withPage { page in
				// Intercept the main page navigation and fulfill it
				try await page.route("**/test-page") { route in
					try await route.fulfill(status: 200, body: "<div id='test'>Hello</div>")
				}

				// Also block CSS
				try await page.route("**/*.css") { route in
					try await route.abort()
				}

				try await page.goto("https://example.com/test-page")
				let text = try await page.locator("#test").textContent()
				#expect(text == "Hello")
			}
		}

		@Test("route.fulfill returns custom response")
		func routeFulfill() async throws {
			try await withPage { page in
				try await page.route("**/mock-api") { route in
					try await route.fulfill(
						status: 200,
						headers: ["content-type": "application/json"],
						body: "{\"value\":42}"
					)
				}

				// Serve a base page first
				try await page.route("**/base") { route in
					try await route.fulfill(status: 200, body: "<html></html>")
				}
				try await page.goto("https://test.local/base")

				let result = try await page.evaluate("""
				fetch('/mock-api').then(r => r.json()).then(d => d.value)
				""", as: Int.self)

				#expect(result == 42)
			}
		}

		@Test("route.continue_ forwards request to network")
		func routeContinue() async throws {
			try await withPage { page in
				try await page.route("**/api-call") { route in
					try await route.continue_()
				}

				// Serve a base page
				try await page.route("**/base") { route in
					try await route.fulfill(status: 200, body: "<html></html>")
				}
				try await page.goto("https://test.local/base")

				// continue_() resolves the route, so the fetch completes with a network error
				// (no real server at test.local). If continue_() didn't resolve the route, the
				// fetch would hang until the AbortSignal fires, yielding "timeout" instead.
				let outcome = try await page.evaluate("""
				fetch('/api-call', { signal: AbortSignal.timeout(5000) })
					.then(() => 'success')
					.catch(e => e.name === 'TimeoutError' ? 'timeout' : 'network-error')
				""", as: String.self)
				#expect(outcome == "network-error", "continue_() should forward to network, not leave the route unresolved")
			}
		}

		@Test("route.request gives access to intercepted request URL")
		func routeRequest() async throws {
			try await withPage { page in
				let requestUrl = Mutex("")

				try await page.route("**/test-endpoint") { route in
					requestUrl.withLock { $0 = route.request?.url ?? "" }
					try await route.fulfill(status: 200, body: "ok")
				}

				// Serve a base page
				try await page.route("**/base") { route in
					try await route.fulfill(status: 200, body: "<html></html>")
				}
				try await page.goto("https://test.local/base")

				_ = try await page.evaluate("fetch('/test-endpoint').then(r => r.text())" as String) as Any?
				let url = requestUrl.withLock { $0 }
				#expect(url.contains("test-endpoint"))
			}
		}

		@Test("later route overrides earlier catch-all for same URL")
		func laterRouteOverridesCatchAll() async throws {
			try await withPage { page in
				let handlerUsed = Mutex("")

				// Serve a base page
				try await page.route("**/base") { route in
					try await route.fulfill(status: 200, body: "<html></html>")
				}

				// Catch-all registered first
				try await page.route("**/*") { route in
					handlerUsed.withLock { $0 = "catch-all" }
					try await route.fulfill(status: 200, body: "catch-all")
				}

				// Narrower route registered second — should win
				try await page.route("**/api/**") { route in
					handlerUsed.withLock { $0 = "api" }
					try await route.fulfill(status: 200, body: "api")
				}

				try await page.goto("https://test.local/base")
				let result = try await page.evaluate("fetch('/api/data').then(r => r.text())", as: String.self)
				#expect(result == "api")
				#expect(handlerUsed.withLock { $0 } == "api")
			}
		}

		@Test("throwing route handler aborts the request immediately")
		func throwingHandlerAbortsRequest() async throws {
			try await withPage { page in
				try await page.route("**/base") { route in
					try await route.fulfill(status: 200, body: "<html></html>")
				}

				// This handler throws without resolving the route
				try await page.route("**/api/data") { _ in
					struct HandlerError: Error {}
					throw HandlerError()
				}

				try await page.goto("https://example.com/base")

				// When a handler throws, the route should be aborted immediately.
				// Bug behavior: route is left unresolved, fetch hangs until the 5s AbortSignal.
				// Fixed behavior: route is aborted, fetch fails in < 1 second.
				let result = try await page.evaluate("""
					(() => {
						const start = Date.now();
						return fetch('/api/data', { signal: AbortSignal.timeout(5000) })
							.then(() => `succeeded:${Date.now() - start}`)
							.catch(() => `failed:${Date.now() - start}`);
					})()
				""", as: String.self)
				let parts = result.split(separator: ":")
				let status = String(parts[0])
				let elapsedMs = Int(parts[1]) ?? 0

				#expect(status == "failed", "Throwing handler should fail the request, not continue to network")
				#expect(elapsedMs < 1000, "Route should be aborted immediately (\(elapsedMs)ms), not hang until timeout")
			}
		}

		@Test("route.abort with specific error code")
		func routeAbortWithErrorCode() async throws {
			try await withPage { page in
				try await page.route("**/base") { route in
					try await route.fulfill(status: 200, body: "<html></html>")
				}

				try await page.route("**/blocked") { route in
					try await route.abort(errorCode: "connectionrefused")
				}

				try await page.goto("https://test.local/base")

				let result = try await page.evaluate("""
					fetch('/blocked').then(() => 'ok').catch(() => 'blocked')
				""", as: String.self)
				#expect(result == "blocked")
			}
		}

		@Test("page.unroute removes route handler")
		func unroute() async throws {
			try await withPage { page in
				// Serve a base page
				try await page.route("**/base") { route in
					try await route.fulfill(status: 200, body: "<html></html>")
				}

				try await page.route("**/test-path") { route in
					try await route.fulfill(status: 200, body: "intercepted")
				}

				try await page.goto("https://test.local/base")

				// First request should be intercepted
				let result1 = try await page.evaluate("fetch('/test-path').then(r => r.text())", as: String.self)
				#expect(result1 == "intercepted")

				// Remove the route
				try await page.unroute("**/test-path")

				// Second request should NOT be intercepted — goes to real server, fetch fails
				let result2 = try await page.evaluate("fetch('/test-path', { signal: AbortSignal.timeout(2000) }).then(r => r.text()).catch(() => 'not-intercepted')", as: String.self)
				#expect(result2 == "not-intercepted")
			}
		}
	}
}
