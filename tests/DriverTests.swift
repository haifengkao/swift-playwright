import Testing
import Foundation
@testable import Playwright

struct DriverTests {
	@Test("Environment variables contain expected values")
	func driverEnvironment() throws {
		let env = Driver.environment()

		#expect(env["PW_LANG_NAME"] == "swift")
		let langVersion = try #require(env["PW_LANG_NAME_VERSION"] as? String)
		#expect(langVersion.contains("."), "PW_LANG_NAME_VERSION should be a dotted version string")
		let cliVersion = try #require(env["PW_CLI_DISPLAY_VERSION"] as? String)
		#expect(cliVersion.contains("."), "PW_CLI_DISPLAY_VERSION should be a dotted version string")
	}

	@Test("PLAYWRIGHT_DRIVER_PATH with missing cli.js throws driverNotFound")
	func driverPathMissingCli() throws {
		#expect {
			_ = try Driver.find(in: ["PLAYWRIGHT_DRIVER_PATH": "/nonexistent/path"])
		} throws: { error in
			guard case PlaywrightError.driverNotFound = error else { return false }
			return true
		}
	}

	@Test("Finds driver with valid program path and cli.js argument")
	func findsDriver() throws {
		let executable = try Driver.find(in: [:])
		#expect(FileManager.default.fileExists(atPath: executable.program), "Program path should exist on disk")
		#expect(executable.arguments.contains(where: { $0.contains("cli.js") }))
	}
}
