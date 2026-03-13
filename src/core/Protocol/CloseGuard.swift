import Foundation

/// Thread-safe, single-use close gate.
///
/// Guarantees that a cleanup block runs exactly once, even if
/// `close()` is called from multiple threads or from both an
/// explicit call and `deinit`.
final class CloseGuard: Sendable {
	private let lock = NSLock()
	private nonisolated(unsafe) var closed = false

	/// Runs `body` exactly once. Subsequent calls are no-ops.
	func closeOnce(_ body: () -> Void) {
		let shouldClose = lock.withLock {
			guard !closed else { return false }
			closed = true
			return true
		}
		if shouldClose { body() }
	}
}
