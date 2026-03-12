import Testing
import Foundation
@testable import Playwright

/// Unit tests for Page.globToRegex, ported from Playwright's canonical test suite.
///
/// See: playwright-core/tests/page/interception.spec.ts
/// See: playwright-dotnet/src/Playwright.Tests/InterceptionTests.cs
@Suite
struct GlobTests {
	/// Helper: compile a glob and test if it matches a URL.
	private func globMatches(_ glob: String, _ url: String) -> Bool {
		let pattern = Page.globToRegex(glob)
		guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
		return regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil
	}

	// MARK: - Basic ** and * matching

	@Test("** matches any path")
	func doubleStarMatchesAnyPath() {
		#expect(globMatches("**/*.js", "https://localhost:8080/foo.js"))
		#expect(!globMatches("**/*.css", "https://localhost:8080/foo.js"))
		#expect(!globMatches("*.js", "https://localhost:8080/foo.js"))
		#expect(globMatches("https://**/*.js", "https://localhost:8080/foo.js"))
		#expect(globMatches("http://localhost:8080/simple/path.js", "http://localhost:8080/simple/path.js"))
	}

	@Test("** matches any path with leading slash")
	func doubleStarMatchesLeadingSlash() {
		#expect(globMatches("**/*.js", "/foo.js"))
		#expect(!globMatches("asd/**.js", "/foo.js"))
	}

	@Test("** does not match without separator before filename")
	func doubleStarNeedsSeparator() {
		// bar_foo.js has no / before the filename, so **/*.js shouldn't match
		#expect(!globMatches("**/*.js", "bar_foo.js"))
	}

	@Test("* does not cross path separators")
	func singleStarDoesNotCrossSlash() {
		#expect(globMatches("foo*", "foo.js"))
		#expect(!globMatches("foo*", "foo/bar.js"))
		#expect(!globMatches("http://localhost:3000/signin-oidc*", "http://localhost:3000/signin-oidc/foo"))
		#expect(globMatches("http://localhost:3000/signin-oidc*", "http://localhost:3000/signin-oidcnice"))
	}

	// MARK: - {a,b} alternation groups

	@Test("{a,b} matches alternatives")
	func braceGroupAlternation() {
		#expect(globMatches("**/{a,b}.js", "https://localhost:8080/a.js"))
		#expect(globMatches("**/{a,b}.js", "https://localhost:8080/b.js"))
		#expect(!globMatches("**/{a,b}.js", "https://localhost:8080/c.js"))
	}

	@Test("{png,jpg,jpeg} matches multiple extensions")
	func braceGroupExtensions() {
		#expect(globMatches("**/*.{png,jpg,jpeg}", "https://localhost:8080/c.jpg"))
		#expect(globMatches("**/*.{png,jpg,jpeg}", "https://localhost:8080/c.jpeg"))
		#expect(globMatches("**/*.{png,jpg,jpeg}", "https://localhost:8080/c.png"))
		#expect(!globMatches("**/*.{png,jpg,jpeg}", "https://localhost:8080/c.css"))
	}

	// MARK: - [] treated as literal (NOT character class)

	@Test("[] is treated as literal characters")
	func bracketsAreLiteral() {
		#expect(globMatches("**/api/v[0-9]", "http://example.com/api/v[0-9]"))
		#expect(!globMatches("**/api/v[0-9]", "http://example.com/api/version"))
	}

	// MARK: - Backslash escaping

	@Test("escaped ? matches literal question mark")
	func escapedQuestionMark() {
		#expect(globMatches("**/api\\?param", "http://example.com/api?param"))
		#expect(!globMatches("**/api\\?param", "http://example.com/api-param"))
	}

	@Test("escaped ? with complex pattern")
	func escapedQuestionMarkComplex() {
		#expect(globMatches(
			"**/three-columns/settings.html\\?**id=settings-**",
			"http://mydomain:8080/blah/blah/three-columns/settings.html?id=settings-e3c58efe-02e9-44b0-97ac-dd138100cf7c&blah"
		))
	}

	// MARK: - ? is literal (NOT a wildcard)

	@Test("? is treated as literal, not a wildcard")
	func questionMarkIsLiteral() {
		#expect(!globMatches("http://playwright.?ev", "http://playwright.dev/"))
		#expect(globMatches("http://playwright.?ev", "http://playwright.?ev"))
		#expect(!globMatches("http://playwright.dev/f??", "http://playwright.dev/foo"))
		#expect(globMatches("http://playwright.dev/f??", "http://playwright.dev/f??"))
	}

	// MARK: - /**/ matches zero-length path segment

	@Test("/**/ matches zero-length path segment")
	func doubleStarSlashMatchesZeroLength() {
		#expect(globMatches("https://foo/**/bar.js", "https://foo/bar.js"))
		#expect(globMatches("https://foo/**/bar.js", "https://foo/x/bar.js"))
		#expect(globMatches("https://foo/**/**/bar.js", "https://foo/bar.js"))
	}

	// MARK: - Exact regex output

	@Test("globToRegex produces correct regex for escape sequences")
	func exactRegexEscapes() {
		#expect(Page.globToRegex("\\?") == "^\\?$")
		#expect(Page.globToRegex("\\\\") == "^\\\\$")
		#expect(Page.globToRegex("\\[") == "^\\[$")
		#expect(Page.globToRegex("[a-z]") == "^\\[a-z\\]$")
	}

	@Test("globToRegex escapes all regex special characters")
	func exactRegexSpecialChars() {
		#expect(Page.globToRegex("$^+.\\*()|\\?\\{\\}\\[\\]") == "^\\$\\^\\+\\.\\*\\(\\)\\|\\?\\{\\}\\[\\]$")
	}

	// MARK: - Wildcard in scheme/domain

	@Test("* matches within scheme")
	func starInScheme() {
		// No trailing slash — pure globToRegex doesn't normalize slashes (urlMatches does)
		#expect(globMatches("h*://playwright.dev", "http://playwright.dev"))
		#expect(globMatches("h*://playwright.dev/", "http://playwright.dev/"))
	}

	@Test("* matches subdomain")
	func starInSubdomain() {
		#expect(globMatches("http://*.playwright.dev/?x=y", "http://api.playwright.dev/?x=y"))
	}

	// MARK: - Comma outside braces is literal

	@Test("comma outside braces is literal")
	func commaOutsideBraces() {
		#expect(globMatches("**/a,b", "https://localhost/a,b"))
		#expect(!globMatches("**/a,b", "https://localhost/a"))
	}

	// MARK: - Custom schemes

	@Test("custom protocol schemes")
	func customSchemes() {
		#expect(globMatches("my.custom.protocol://**", "my.custom.protocol://foo"))
		#expect(globMatches("f*e://**", "file:///foo/"))
	}

	// MARK: - Trailing ** after /

	@Test("trailing /** matches anything after path")
	func trailingDoubleStar() {
		#expect(globMatches("**/foo/**", "http://playwright.dev/foo/bar"))
		#expect(globMatches("**/foo/**", "http://playwright.dev/foo/bar/baz"))
	}

	// MARK: - Single backslash at end

	@Test("single backslash at end is literal")
	func trailingBackslash() {
		#expect(Page.globToRegex("\\") == "^\\\\$")
	}
}
