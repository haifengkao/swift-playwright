import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct ConnectionTests {
		@Test("Connection sends requests and receives matching responses")
		func requestResponse() async throws {
			let server = try await PlaywrightServer.launch()
			let transport = Transport.connect(to: server)
			let connection = Connection(transport: transport)

			await connection.start()

			// Setup: initialize and launch a browser (serial — needed for setup)
			let initResult = try await connection.sendMessage(
				guid: "",
				method: "initialize",
				params: ["sdkLanguage": Driver.sdkLanguage]
			)

			let playwrightRef = try #require(initResult["playwright"] as? [String: Any])
			let playwrightGuid = try #require(playwrightRef["guid"] as? String)
			let playwrightObj = try #require(await connection.getObject(playwrightGuid))
			let chromiumGuid = try #require((playwrightObj.initializer["chromium"] as? [String: Any])?["guid"] as? String)

			let launchResult = try await connection.sendMessage(
				guid: chromiumGuid,
				method: "launch",
				params: ["headless": true, "timeout": timeoutMs(.seconds(180))] as [String: Any]
			)

			let browserRef = try #require(launchResult["browser"] as? [String: Any])
			let browserGuid = try #require(browserRef["guid"] as? String)

			// Send two newContext requests concurrently to exercise response correlation
			async let context1Result = connection.sendMessage(
				guid: browserGuid,
				method: "newContext",
				params: ["timeout": timeoutMs(), "noDefaultBrowserArgs": false] as [String: Any]
			)
			async let context2Result = connection.sendMessage(
				guid: browserGuid,
				method: "newContext",
				params: ["timeout": timeoutMs(), "noDefaultBrowserArgs": false] as [String: Any]
			)

			let (result1, result2) = try await (context1Result, context2Result)

			// Each response must contain a valid, distinct context GUID
			let guid1 = try #require((result1["context"] as? [String: Any])?["guid"] as? String, "First response should contain a context GUID")
			let guid2 = try #require((result2["context"] as? [String: Any])?["guid"] as? String, "Second response should contain a context GUID")
			#expect(guid1 != guid2, "Concurrent requests should receive distinct responses")

			await connection.close()
		}

		@Test("Connection registers objects from __create__ messages")
		func objectRegistration() async throws {
			let server = try await PlaywrightServer.launch()
			let transport = Transport.connect(to: server)
			let connection = Connection(transport: transport)

			await connection.start()

			let result = try await connection.sendMessage(
				guid: "",
				method: "initialize",
				params: ["sdkLanguage": Driver.sdkLanguage]
			)

			// Objects referenced in the response should be retrievable by GUID
			let playwrightGuid = try #require((result["playwright"] as? [String: Any])?["guid"] as? String)
			let playwrightObj = try #require(await connection.getObject(playwrightGuid), "Registered object should be retrievable by GUID")

			// Child objects referenced in initializers should also be in the registry
			let chromiumGuid = try #require((playwrightObj.initializer["chromium"] as? [String: Any])?["guid"] as? String)
			#expect(await connection.getObject(chromiumGuid) != nil, "Child object should be in registry")

			// Unknown GUIDs return nil
			#expect(await connection.getObject("nonexistent-guid-12345") == nil, "Unknown GUID should return nil")

			await connection.close()
		}
	}
}
