import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct TransportTests {
		@Test("Transport deframes length-prefixed messages into valid JSON payloads")
		func deframeMessages() async throws {
			let server = try await PlaywrightServer.launch()
			let transport = Transport.connect(to: server)
			defer { transport.close() }

			try transport.send([
				"id": 1,
				"guid": "",
				"method": "initialize",
				"params": ["sdkLanguage": Driver.sdkLanguage],
				"metadata": [
					"wallTime": Int(Date().timeIntervalSince1970 * 1000),
					"apiName": "",
					"internal": true,
				] as [String: Any],
			] as [String: Any])

			// Each yielded payload should be a complete, valid JSON object —
			// proving the 4-byte LE length-prefix deframing produces correctly-bounded payloads.
			var messageCount = 0
			for await payload in transport.messages {
				let message = try #require(
					try JSONSerialization.jsonObject(with: payload) as? [String: Any],
					"Each deframed payload should be valid JSON"
				)
				messageCount += 1

				if message["id"] as? Int == 1 { break }
			}

			#expect(messageCount > 1, "Should deframe multiple messages from the stream")
		}
	}
}
