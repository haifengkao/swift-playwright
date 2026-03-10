import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct ServerLifecycleTests {
		@Test("Server launches and can be closed")
		func launchAndClose() async throws {
			let server = try await PlaywrightServer.launch()
			#expect(server.isRunning)
			server.close()
			#expect(!server.isRunning)
		}

		@Test("Multiple launch/close cycles work without issues")
		func multipleCycles() async throws {
			for _ in 0..<3 {
				let server = try await PlaywrightServer.launch()
				#expect(server.isRunning)
				server.close()
				#expect(!server.isRunning)
			}
		}
	}
}
