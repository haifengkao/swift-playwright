import Foundation
import PackagePlugin

@main
struct PlaywrightDriverPlugin: CommandPlugin {
	func performCommand(context: PluginContext, arguments: [String]) throws {
		let tool = try context.tool(named: "DownloadDriver")

		let process = Process()
		process.executableURL = URL(fileURLWithPath: tool.url.path())
		process.arguments = [
			"--cache-dir", playwrightPackageDirectory(context: context).appending(path: "src/core/drivers").path(),
		] + arguments

		try process.run()
		process.waitUntilExit()

		guard process.terminationStatus == 0 else {
			Diagnostics.error("Failed to install Playwright driver")
			return
		}
	}

	private func playwrightPackageDirectory(context: PluginContext) -> URL {
		if context.package.targets.contains(where: { $0.name == "Playwright" }) {
			return context.package.directoryURL
		}

		if let dir = findPlaywrightDependency(in: context.package.dependencies) {
			return dir
		}

		return context.package.directoryURL
	}

	private func findPlaywrightDependency(in deps: [PackageDependency]) -> URL? {
		for dep in deps {
			if dep.package.targets.contains(where: { $0.name == "Playwright" }) {
				return dep.package.directoryURL
			}

			if let found = findPlaywrightDependency(in: dep.package.dependencies) {
				return found
			}
		}

		return nil
	}
}
