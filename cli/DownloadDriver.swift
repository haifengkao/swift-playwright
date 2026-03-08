import Foundation
import ArgumentParser
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The Playwright version to be downloaded
///
/// > NOTE: When changing this, remember to also update `Driver.playwrightVersion`
private let playwrightVersion = "1.58.2"

@main
struct DownloadDriver: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Download the Playwright driver for browser automation."
	)

	@Option(name: .long, help: "Directory to install the downloaded driver.")
	var cacheDir: String

	mutating func run() async throws {
		guard let platform = detectPlatform() else {
			throw ValidationError("Unsupported platform")
		}

		let driverDir = "\(cacheDir)/playwright-\(playwrightVersion)-\(platform)"
		let sentinel = "\(driverDir)/package/cli.js"

		if FileManager.default.fileExists(atPath: sentinel) {
			print("Playwright driver v\(playwrightVersion) already installed at \(driverDir)")
			return
		}

		try FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)

		print("Downloading Playwright driver v\(playwrightVersion) (\(platform))...")

		let zipPath = "\(cacheDir)/playwright-\(playwrightVersion)-\(platform).zip"
		try await download(
			from: URL(string: "https://cdn.playwright.dev/builds/driver/playwright-\(playwrightVersion)-\(platform).zip")!,
			to: zipPath
		)

		try FileManager.default.createDirectory(atPath: driverDir, withIntermediateDirectories: true)

		let unzip = Process()
		unzip.standardError = FileHandle.nullDevice
		unzip.standardOutput = FileHandle.nullDevice
		unzip.arguments = ["-o", "-q", zipPath, "-d", driverDir]
		unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")

		try unzip.run()
		unzip.waitUntilExit()

		guard unzip.terminationStatus == 0 else {
			try? FileManager.default.removeItem(atPath: driverDir)
			throw CleanExit.message("Error: unzip exited with status \(unzip.terminationStatus)")
		}

		try? FileManager.default.removeItem(atPath: zipPath)

		guard FileManager.default.fileExists(atPath: sentinel) else {
			throw CleanExit.message("Error: extracted driver missing expected file at \(sentinel)")
		}

		print("Playwright driver v\(playwrightVersion) installed at \(driverDir)")
	}
}

// MARK: - Helpers

private func detectPlatform() -> String? {
	#if os(macOS)
	#if arch(arm64)
	return "mac-arm64"
	#elseif arch(x86_64)
	return "mac"
	#else
	return nil
	#endif
	#elseif os(Linux)
	#if arch(arm64)
	return "linux-arm64"
	#elseif arch(x86_64)
	return "linux"
	#else
	return nil
	#endif
	#else
	return nil
	#endif
}

private func download(from url: URL, to destination: String) async throws {
	let (tempURL, response) = try await URLSession(configuration: .ephemeral).download(from: url)

	if let http = response as? HTTPURLResponse, http.statusCode != 200 {
		throw ValidationError("Download failed with HTTP \(http.statusCode)")
	}

	try? FileManager.default.removeItem(atPath: destination)
	try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: destination))
}
