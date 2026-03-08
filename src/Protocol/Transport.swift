import Foundation

/// Handles length-prefixed message framing over stdio pipes.
///
/// The Playwright protocol uses a simple framing format:
/// - 4-byte little-endian unsigned integer indicating payload length
/// - Payload of exactly that length (JSON bytes)
///
/// The transport is responsible only for framing — it yields raw `Data`
/// payloads without interpreting them. JSON parsing is handled by the
/// ``Connection`` layer.
///
/// This matches the transport used by playwright-python, playwright-java,
/// and playwright-dotnet.
///
/// See: https://github.com/microsoft/playwright-python/blob/main/playwright/_impl/_transport.py
final class Transport: Sendable {
	/// Raw JSON payloads received from the server (after removing the length prefix).
	let messages: AsyncStream<Data>

	private let server: PlaywrightServer
	private let closeGuard = CloseGuard()
	private let readTask: Task<Void, Never>
	private let messagesContinuation: AsyncStream<Data>.Continuation

	private init(
		server: PlaywrightServer,
		messages: AsyncStream<Data>,
		messagesContinuation: AsyncStream<Data>.Continuation,
		readTask: Task<Void, Never>
	) {
		self.server = server
		self.messages = messages
		self.readTask = readTask
		self.messagesContinuation = messagesContinuation
	}

	deinit { close() }

	/// Creates a transport connected to the given server's stdio pipes.
	///
	/// Immediately starts a background task to read and deframe incoming
	/// messages from the server's stdout.
	static func connect(to server: PlaywrightServer) -> Transport {
		let (messages, continuation) = AsyncStream<Data>.makeStream()

		let readTask = Task {
			var buffer = Data()

			for await chunk in server.messages {
				buffer.append(chunk)

				// Parse as many complete frames as possible
				var offset = 0
				while offset + 4 <= buffer.count {
					let length = buffer[offset..<offset + 4].withUnsafeBytes {
						Int($0.loadUnaligned(as: UInt32.self).littleEndian)
					}

					guard offset + 4 + length <= buffer.count else {
						break // Incomplete frame, wait for more data
					}

					let payload = buffer.subdata(in: (offset + 4)..<(offset + 4 + length))
					offset += 4 + length

					continuation.yield(payload)
				}

				if offset > 0 { buffer.removeSubrange(0..<offset) }
			}

			continuation.finish()
		}

		return Transport(server: server, messages: messages, messagesContinuation: continuation, readTask: readTask)
	}

	/// Sends raw bytes to the server with length-prefix framing.
	///
	/// The data is framed with a 4-byte little-endian length prefix
	/// before writing to the server's stdin.
	///
	/// - Parameter data: The raw payload to send (typically JSON bytes).
	func send(_ data: Data) {
		var frame = Data(capacity: 4 + data.count)

		// 4-byte little-endian length prefix
		var length = UInt32(data.count).littleEndian
		withUnsafeBytes(of: &length) { frame.append(contentsOf: $0) }
		frame.append(data)

		server.write(frame)
	}

	/// Convenience: serializes a JSON object and sends it with framing.
	func send(_ message: [String: Any]) throws {
		try send(JSONSerialization.data(withJSONObject: message))
	}

	/// Shuts down the transport and the underlying server.
	func close() {
		closeGuard.closeOnce {
			readTask.cancel()
			messagesContinuation.finish()
			server.close()
		}
	}
}
