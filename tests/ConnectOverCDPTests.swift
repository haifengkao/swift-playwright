import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct ConnectOverCDPTests {
		@Test("connectOverCDP throws on non-Chromium browsers", arguments: ["firefox", "webkit"])
		func rejectsNonChromium(browserName: String) async throws {
			let playwright = try await Playwright.launch()
			defer { Task { await playwright.close() } }

			await #expect(throws: PlaywrightError.invalidArgument("Connecting over CDP is only supported in Chromium.")) {
				_ = try await browserType(named: browserName, from: playwright).connectOverCDP("http://localhost:9222")
			}
		}

		@Test("connectOverCDP connects to a Chromium browser with remote debugging")
		func connectsToChromium() async throws {
			let playwright = try await Playwright.launch()
			defer { Task { await playwright.close() } }

			// Launch Chromium directly with remote debugging enabled
			let executablePath = playwright.chromium.executablePath
			let process = Process()
			process.executableURL = URL(fileURLWithPath: executablePath)
			var args = [
				"--headless",
				"--no-first-run",
				"--remote-debugging-port=0",
				"--no-default-browser-check",
			]
			#if os(Linux)
			args += ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"]
			#endif
			process.arguments = args

			let stderrPipe = Pipe()
			process.standardError = stderrPipe
			process.standardOutput = FileHandle.nullDevice
			try process.run()
			defer { process.terminate() }

			// Parse the WebSocket URL from stderr ("DevTools listening on ws://...")
			let wsEndpoint: String = try await Task.detached {
				var accumulated = Data()
				while true {
					let data = stderrPipe.fileHandleForReading.availableData
					if data.isEmpty { throw PlaywrightError.serverError("Chromium exited before providing a DevTools URL") }

					accumulated.append(data)

					if let output = String(data: accumulated, encoding: .utf8),
					   let range = output.range(of: "DevTools listening on "),
					   let endRange = output[range.upperBound...].range(of: "\n")
					{
						return String(output[range.upperBound..<endRange.lowerBound])
					}
				}
			}
			.value

			// Connect over CDP
			let cdpBrowser = try await playwright.chromium.connectOverCDP(wsEndpoint)
			#expect(cdpBrowser.isConnected)
			#expect(!cdpBrowser.version.isEmpty)
			#expect(cdpBrowser.browserType === playwright.chromium)

			// The connected browser should have at least one context (the default)
			#expect(!cdpBrowser.contexts.isEmpty)

			try await cdpBrowser.close()
		}
	}
}
