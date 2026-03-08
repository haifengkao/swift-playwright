import Foundation

/// Manages discovery of the Playwright driver binary.
///
/// The driver consists of a Node.js binary and the Playwright CLI package.
/// It can be located via environment variables or the SPM resource bundle.
///
/// See: https://playwright.dev/docs/api/class-playwright
enum Driver {
	/// A resolved executable and its arguments for launching the Playwright server.
	struct Executable {
		/// The path to the bundled Node.js binary.
		let program: String
		/// Arguments to pass (e.g. ["cli.js", "run-driver"]).
		let arguments: [String]
	}

	/// Finds the Playwright driver executable.
	///
	/// Search order:
	/// 1. `PLAYWRIGHT_DRIVER_PATH` environment variable
	/// 2. Resource bundle (bundled via SPM `.copy("drivers")` — portable with binary)
	///
	/// - Throws: ``PlaywrightError/driverNotFound(_:)`` if the driver cannot be located.
	/// - Returns: The resolved executable and arguments.
	static func find(in env: [String: String] = ProcessInfo.processInfo.environment) throws -> Executable {
		if let driverPath = env["PLAYWRIGHT_DRIVER_PATH"] {
			guard let executable = resolveDriver(in: URL(fileURLWithPath: driverPath)) else {
				throw PlaywrightError.driverNotFound(
					"PLAYWRIGHT_DRIVER_PATH is set to '\(driverPath)' but no driver found there"
				)
			}

			return executable
		}

		guard let executable = findInResourceBundle() else {
			throw PlaywrightError.driverNotFound(
				"Playwright driver not installed. Run: swift package install-playwright"
			)
		}

		return executable
	}

	/// Looks for the driver in the SPM resource bundle.
	///
	/// When the driver is present in `src/drivers/` at build time,
	/// SPM bundles it via `.copy("drivers")` into `Playwright_Playwright.bundle`.
	/// This bundle travels with the compiled binary, making the driver portable.
	private static func findInResourceBundle() -> Executable? {
		if let driversURL = Bundle.module.url(forResource: "drivers", withExtension: nil) {
			return resolveDriver(in: driversURL.appending(path: "playwright-\(playwrightVersion)-\(platform)"))
		}

		return nil
	}

	/// The platform identifier matching the Playwright CDN naming convention.
	///
	/// > NOTE: Keep this synced with `detectPlatform()` in DownloadDriver.
	private static let platform: String = {
		#if os(macOS)
		#if arch(arm64)
		return "mac-arm64"
		#elseif arch(x86_64)
		return "mac"
		#else
		return "unknown"
		#endif
		#elseif os(Linux)
		#if arch(arm64)
		return "linux-arm64"
		#elseif arch(x86_64)
		return "linux"
		#else
		return "unknown"
		#endif
		#else
		return "unknown"
		#endif
	}()

	/// Checks whether a driver directory contains the expected node binary and CLI script.
	private static func resolveDriver(in driverDir: URL) -> Executable? {
		let nodePath = driverDir.appending(path: "node")
		let cliPath = driverDir.appending(path: "package/cli.js")

		if FileManager.default.fileExists(atPath: cliPath.path), FileManager.default.fileExists(atPath: nodePath.path) {
			return Executable(program: nodePath.path, arguments: [cliPath.path, "run-driver"])
		}

		return nil
	}

	/// Environment variables to set when launching the Playwright server.
	static func environment() -> [String: String?] {
		[
			"PW_LANG_NAME": "swift",
			"PW_LANG_NAME_VERSION": swiftVersion,
			"PW_CLI_DISPLAY_VERSION": packageVersion,
		]
	}

	/// The SDK language identifier sent in the initialize handshake.
	/// The server currently only accepts javascript|python|java|csharp
	static let sdkLanguage = "python"

	// TODO: Retrieve dynamically from Package.swift
	private static let swiftVersion: String = {
		#if swift(>=6.2)
		"6.2"
		#elseif swift(>=6.1)
		"6.1"
		#elseif swift(>=6.0)
		"6.0"
		#elseif swift(>=5.10)
		"5.10"
		#else
		"unknown"
		#endif
	}()
	/// Updated by the release preparation agent when cutting a new version.
	private static let packageVersion = "0.1.0"

	/// The currently-supported Playwright driver version, which determines the CLI version and API contract.
	///
	/// > NOTE: When changing this, remember to also update `DownloadDriver`
	static let playwrightVersion = "1.58.2"
}
