import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct ConcurrencyTests {
		@Test("concurrent evaluate calls return correct results")
		func concurrentEvaluate() async throws {
			try await withPage { page in
				let delayMs = 200
				let clock = ContinuousClock()
				let start = clock.now

				try await withThrowingTaskGroup(of: (Int, Int).self) { group in
					for i in 0..<5 {
						group.addTask {
							let result: Int = try await page.evaluate(
								"(x) => new Promise(r => setTimeout(() => r(x * 2), \(delayMs)))", arg: i
							)
							return (i, result)
						}
					}

					var results: [Int: Int] = [:]
					for try await (input, output) in group {
						results[input] = output
					}

					for i in 0..<5 {
						#expect(results[i] == i * 2)
					}
				}

				let elapsed = clock.now - start
				#expect(elapsed < .milliseconds(5 * delayMs), "Evaluates should overlap, not run serially")
			}
		}

		@Test("concurrent newPage calls produce distinct pages without corruption")
		func concurrentNewPage() async throws {
			try await withContext { context in
				try await withThrowingTaskGroup(of: Page.self) { group in
					for _ in 0..<3 {
						group.addTask {
							try await context.newPage()
						}
					}

					var pages: [Page] = []
					for try await page in group {
						pages.append(page)
					}

					#expect(pages.count == 3)
					#expect(context.pages.count == 3)
					// All pages should be distinct objects
					for i in 0..<pages.count {
						for j in (i + 1)..<pages.count {
							#expect(pages[i] !== pages[j])
						}
					}
				}
			}
		}

		@Test("concurrent evaluate on different pages returns correct results")
		func concurrentEvaluateMultiplePages() async throws {
			try await withContext { context in
				let page1 = try await context.newPage()
				let page2 = try await context.newPage()

				let delayMs = 200
				let clock = ContinuousClock()
				let start = clock.now

				try await withThrowingTaskGroup(of: (String, String).self) { group in
					group.addTask {
						try await page1.setContent("<title>Page 1</title>")
						let title: String = try await page1.evaluate(
							"() => new Promise(r => setTimeout(() => r(document.title), \(delayMs)))"
						)
						return ("page1", title)
					}
					group.addTask {
						try await page2.setContent("<title>Page 2</title>")
						let title: String = try await page2.evaluate(
							"() => new Promise(r => setTimeout(() => r(document.title), \(delayMs)))"
						)
						return ("page2", title)
					}

					var results: [String: String] = [:]
					for try await (key, value) in group {
						results[key] = value
					}

					#expect(results["page1"] == "Page 1")
					#expect(results["page2"] == "Page 2")
				}

				let elapsed = clock.now - start
				#expect(elapsed < .milliseconds(3 * delayMs), "Evaluates on different pages should overlap, not run serially")
			}
		}
	}
}
