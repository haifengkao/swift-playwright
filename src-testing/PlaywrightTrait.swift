import Testing

/// A Swift Testing trait for configuring Playwright assertion behavior.
///
/// ```swift
/// @Suite(.playwright(timeout: .seconds(10)))
/// struct MyTests {
///     @Test func example() async throws {
///         try await expect(locator).toBeVisible()  // Uses 10s timeout
///     }
/// }
/// ```
public struct PlaywrightTrait: SuiteTrait, TestTrait {
	public let isRecursive = true

	/// The default assertion timeout for tests using this trait.
	public let timeout: Duration?
}

extension Trait where Self == PlaywrightTrait {
	/// Configures Playwright assertion defaults for a test or suite.
	///
	/// - Parameter timeout: The default timeout for assertions. Overrides the global default of 5 seconds.
	public static func playwright(timeout: Duration? = nil) -> Self {
		PlaywrightTrait(timeout: timeout)
	}
}

/// Resolves the effective timeout for an assertion.
///
/// Priority: explicit parameter > PlaywrightTrait on current test > 5 seconds default.
func resolveTimeout(_ explicit: Duration?) -> Duration {
	if let explicit { return explicit }

	if let test = Test.current,
	   let trait = test.traits.last(where: { $0 is PlaywrightTrait }) as? PlaywrightTrait,
	   let timeout = trait.timeout
	{
		return timeout
	}

	return .seconds(5)
}
