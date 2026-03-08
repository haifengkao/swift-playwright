import Testing
import Foundation
@testable import Playwright

struct ConnectionTests {
	@Test("Connection sends initialize and receives correlated response", .timeLimit(.minutes(1)))
	func initializeHandshake() async throws {
		let server = try await PlaywrightServer.launch()
		let transport = Transport.connect(to: server)
		let connection = Connection(transport: transport)

		await connection.start()

		let result = try await connection.sendMessage(
			guid: "",
			method: "initialize",
			params: ["sdkLanguage": Driver.sdkLanguage]
		)

		// The response should contain {"playwright": {"guid": "playwright@..."}}
		let playwrightRef = result["playwright"] as? [String: Any]
		#expect(playwrightRef != nil, "Response should contain 'playwright' key")

		let playwrightGuid = playwrightRef?["guid"] as? String
		#expect(playwrightGuid != nil, "Playwright ref should have a GUID")
	}

	@Test("Connection registers objects from __create__ messages", .timeLimit(.minutes(1)))
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

		// After initialize, the connection should have registered objects
		let playwrightGuid = (result["playwright"] as? [String: Any])?["guid"] as? String
		#expect(playwrightGuid != nil)

		let playwrightObj = await connection.getObject(playwrightGuid!)
		#expect(playwrightObj != nil, "Playwright object should be in registry")
		#expect(playwrightObj?.type == "Playwright")

		// The Playwright object's initializer should contain browser type GUIDs
		let chromiumRef = playwrightObj?.initializer["chromium"] as? [String: Any]
		let chromiumGuid = chromiumRef?["guid"] as? String
		#expect(chromiumGuid != nil, "Playwright initializer should reference chromium")

		let chromiumObj = await connection.getObject(chromiumGuid!)
		#expect(chromiumObj is BrowserType, "Chromium object should be a BrowserType")
	}
}
