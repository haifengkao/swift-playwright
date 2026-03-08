import Testing
import Foundation
@testable import Playwright

struct ServerLifecycleTests {
	@Test("Server launches and can be closed", .timeLimit(.minutes(1)))
	func launchAndClose() async throws {
		let server = try await PlaywrightServer.launch()
		server.close()
	}

	@Test("Multiple launch/close cycles work without issues", .timeLimit(.minutes(1)))
	func multipleCycles() async throws {
		for _ in 0..<3 {
			let server = try await PlaywrightServer.launch()
			server.close()
		}
	}
}
