import Foundation

extension Duration {
	/// The total number of milliseconds represented by this duration, as a `Double`.
	var milliseconds: Double {
		let (seconds, attoseconds) = components
		return Double(seconds) * 1000 + Double(attoseconds) / 1_000_000_000_000_000
	}
}
