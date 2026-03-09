import Foundation

/// Options for launching a browser via `BrowserType.launch()`.
///
/// All properties are optional — omitted values use Playwright's defaults.
///
/// ```swift
/// let browser = try await playwright.chromium.launch(.init(headless: false))
/// ```
///
/// See: https://playwright.dev/docs/api/class-browsertype#browser-type-launch
public struct LaunchOptions: Sendable {
	/// Whether to run the browser in headless mode. Defaults to `true`.
	public var headless: Bool?

	/// Browser distribution channel (e.g. `"chrome"`, `"msedge"`).
	public var channel: String?

	/// Additional arguments to pass to the browser instance.
	public var args: [String]?

	/// Maximum time to wait for the browser to start.
	/// Defaults to 3 minutes if not specified.
	public var timeout: Duration?

	/// Path to the browser executable.
	public var executablePath: String?

	/// Environment variables to set for the browser process.
	public var env: [String: String]?

	/// Slows down operations by the specified amount.
	public var slowMo: Duration?

	public init(
		headless: Bool? = nil,
		channel: String? = nil,
		args: [String]? = nil,
		timeout: Duration? = nil,
		executablePath: String? = nil,
		env: [String: String]? = nil,
		slowMo: Duration? = nil
	) {
		self.env = env
		self.args = args
		self.slowMo = slowMo
		self.channel = channel
		self.timeout = timeout
		self.headless = headless
		self.executablePath = executablePath
	}

	/// Converts to the protocol dictionary format, omitting nil values.
	///
	/// The `timeout` field is always included because the Playwright server requires it.
	/// Defaults to 180000ms (3 minutes), matching Playwright's launch timeout.
	func toProtocol() -> [String: Any] {
		var params: [String: Any] = [
			"timeout": (timeout ?? .seconds(180)).milliseconds,
		]

		if let args { params["args"] = args }
		if let channel { params["channel"] = channel }
		if let headless { params["headless"] = headless }
		if let slowMo { params["slowMo"] = slowMo.milliseconds }
		if let executablePath { params["executablePath"] = executablePath }
		if let env { params["env"] = env.map { ["name": $0.key, "value": $0.value] } }

		return params
	}
}
