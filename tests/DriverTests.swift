import Testing
import Foundation
@testable import Playwright

struct DriverTests {
	@Test("Environment variables are set correctly")
	func driverEnvironment() {
		let env = Driver.environment()

		#expect(env["PW_LANG_NAME"] == "swift")
		#expect(env["PW_LANG_NAME_VERSION"] != nil)
		#expect(env["PW_CLI_DISPLAY_VERSION"] != nil)
	}

	@Test("PLAYWRIGHT_DRIVER_PATH with missing cli.js throws driverNotFound")
	func driverPathMissingCli() throws {
		#expect(throws: PlaywrightError.self) {
			_ = try Driver.find(in: ["PLAYWRIGHT_DRIVER_PATH": "/nonexistent/path"])
		}
	}

	@Test("Finds driver when installed")
	func findsDriver() throws {
		let executable = try Driver.find(in: [:])
		#expect(executable.arguments.contains(where: { $0.contains("cli.js") }))
	}
}
