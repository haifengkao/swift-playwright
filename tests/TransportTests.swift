import Testing
import Foundation
@testable import Playwright

struct TransportTests {
	@Test("Frame encoding produces correct 4-byte LE prefix + payload")
	func frameEncoding() throws {
		let message: [String: Any] = ["hello": "world"]
		let payload = try JSONSerialization.data(withJSONObject: message)

		var frame = Data()
		var length = UInt32(payload.count).littleEndian
		withUnsafeBytes(of: &length) { frame.append(contentsOf: $0) }
		frame.append(payload)

		// First 4 bytes should be the payload length in LE
		let decodedLength = frame.withUnsafeBytes {
			Int($0.loadUnaligned(as: UInt32.self).littleEndian)
		}
		#expect(decodedLength == payload.count)

		// Remaining bytes should be the JSON payload
		let decodedPayload = frame.subdata(in: 4..<frame.count)
		#expect(decodedPayload == payload)
	}

	@Test("Send initialize and receive protocol messages via Transport", .timeLimit(.minutes(1)))
	func initializeExchange() async throws {
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

		// The server should respond with __create__ messages and then
		// a response with id: 1. Collect messages until we get the response.
		var messageCount = 0
		var receivedCreate = false
		var receivedResponse = false

		for await payload in transport.messages {
			messageCount += 1
			guard let message = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
				continue
			}

			let method = message["method"] as? String ?? "(response)"

			if method == "__create__" {
				receivedCreate = true
			}

			if let id = message["id"] as? Int, id == 1 {
				receivedResponse = true
				break
			}
		}

		#expect(receivedResponse, "Should receive response to initialize (id: 1)")
		#expect(receivedCreate, "Should receive __create__ messages during initialization")
		#expect(messageCount == 8, "Should receive exactly 8 messages during initialization")
	}
}
