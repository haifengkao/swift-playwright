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
							let result = try await page.evaluate(
								"(x) => new Promise(r => setTimeout(() => r(x * 2), \(delayMs)))", arg: i, as: Int.self
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
				#expect(elapsed < .seconds(3), "Evaluates should overlap, not run serially (serial would be ~5×\(delayMs)ms)")
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
	}
}
