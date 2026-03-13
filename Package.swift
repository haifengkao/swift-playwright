// swift-tools-version: 6.1

import PackageDescription

let package = Package(
	name: "Playwright",
	platforms: [.macOS(.v15)],
	products: [
		.library(name: "Playwright", targets: ["Playwright"]),
		.library(name: "PlaywrightTesting", targets: ["PlaywrightTesting"]),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
	],
	targets: [
		// Library
		.target(name: "Playwright", path: "./src", resources: [.copy("drivers")]),
		.target(name: "PlaywrightTesting", dependencies: ["Playwright"], path: "./src-testing"),
		.testTarget(name: "PlaywrightTests", dependencies: ["Playwright", "PlaywrightTesting"], path: "./tests"),

		// Driver Downloader
		.executableTarget(
			name: "DownloadDriver",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
			],
			path: "./cli"
		),
		.plugin(
			name: "PlaywrightDriverPlugin",
			capability: .command(
				intent: .custom(
					verb: "install-playwright",
					description: "Download the Playwright driver for browser automation"
				),
				permissions: [
					.writeToPackageDirectory(reason: "Downloads the Playwright driver"),
					.allowNetworkConnections(
						scope: .all(ports: [443]),
						reason: "Downloads the Playwright driver from cdn.playwright.dev"
					),
				]
			),
			dependencies: ["DownloadDriver"],
			path: "./plugin"
		),

	],
	swiftLanguageModes: [.v6]
)
