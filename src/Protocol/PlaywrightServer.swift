import Foundation

/// Manages the Playwright server subprocess lifecycle.
///
/// The server communicates via JSON-RPC over stdio pipes using
/// length-prefixed JSON messages. Launch with ``launch()``
/// and shut down with ``close()``.
///
/// The subprocess stays alive as long as this object exists. Call ``close()``
/// or let the object deinitialize to terminate the server.
///
/// See: https://playwright.dev/docs/api/class-playwright
final class PlaywrightServer: Sendable {
	/// Raw data chunks from the server's stdout, delivered via dispatch.
	let messages: AsyncStream<Data>

	private let process: Process
	private let stdinHandle: FileHandle
	private let stdoutHandle: FileHandle
	private let stderrHandle: FileHandle
	private let closeGuard = CloseGuard()
	private let continuation: AsyncStream<Data>.Continuation

	private init(
		process: Process,
		stdinHandle: FileHandle,
		stdoutHandle: FileHandle,
		stderrHandle: FileHandle,
		messages: AsyncStream<Data>,
		continuation: AsyncStream<Data>.Continuation
	) {
		self.process = process
		self.messages = messages
		self.stdinHandle = stdinHandle
		self.stdoutHandle = stdoutHandle
		self.stderrHandle = stderrHandle
		self.continuation = continuation
	}

	deinit { close() }

	/// Launches the Playwright server as a child process.
	///
	/// The server is started with the `run-driver` subcommand. The method
	/// returns only after the subprocess is running and stdio pipes are ready.
	///
	/// - Throws: ``PlaywrightError/driverNotFound(_:)`` if the driver cannot be located.
	/// - Returns: A running server instance with valid stdin/stdout handles.
	static func launch() async throws -> PlaywrightServer {
		let executable = try Driver.find()

		let proc = Process()
		if executable.program.contains("/") {
			proc.arguments = executable.arguments
			proc.executableURL = URL(fileURLWithPath: executable.program)
		} else {
			proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
			proc.arguments = [executable.program] + executable.arguments
		}

		// Set environment
		var env = ProcessInfo.processInfo.environment
		for (key, value) in Driver.environment() {
			if let value { env[key] = value } else { env.removeValue(forKey: key) }
		}
		proc.environment = env

		let stdinPipe = Pipe()
		let stderrPipe = Pipe()
		let stdoutPipe = Pipe()
		proc.standardInput = stdinPipe
		proc.standardError = stderrPipe
		proc.standardOutput = stdoutPipe

		let (messages, continuation) = AsyncStream<Data>.makeStream()
		let readHandle = stdoutPipe.fileHandleForReading
		readHandle.readabilityHandler = { handle in
			let data = handle.availableData
			if data.isEmpty {
				// EOF: pipe closed
				handle.readabilityHandler = nil
				continuation.finish()
			} else {
				continuation.yield(data)
			}
		}

		try proc.run()

		// brief pause to catch immediate failures (broken cli.js, missing deps, etc.)
		try await Task.sleep(for: .milliseconds(50))
		guard proc.isRunning else {
			let stderrData = stderrPipe.fileHandleForReading.availableData
			let stderr = String(data: stderrData, encoding: .utf8)
			throw PlaywrightError.driverExitedEarly(status: proc.terminationStatus, stderr: stderr)
		}

		// Drain stderr to prevent the server from blocking on a full pipe buffer
		let stderrReadHandle = stderrPipe.fileHandleForReading
		stderrReadHandle.readabilityHandler = { handle in
			// TODO: Should we be logging this somewhere?
			_ = handle.availableData
		}

		return PlaywrightServer(
			process: proc,
			stdinHandle: stdinPipe.fileHandleForWriting,
			stdoutHandle: readHandle,
			stderrHandle: stderrReadHandle,
			messages: messages,
			continuation: continuation
		)
	}

	/// Sends raw bytes to the server's stdin.
	func write(_ data: Data) {
		stdinHandle.write(data)
	}

	/// Shuts down the Playwright server.
	func close() {
		closeGuard.closeOnce {
			stdoutHandle.readabilityHandler = nil
			stderrHandle.readabilityHandler = nil
			continuation.finish()

			stdinHandle.closeFile()
			stdoutHandle.closeFile()
			stderrHandle.closeFile()

			process.terminate()
		}
	}
}
