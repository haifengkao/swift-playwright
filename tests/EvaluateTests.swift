import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct EvaluateTests {
		@Test("page.evaluate returns a number")
		func evaluateNumber() async throws {
			try await withPage { page in
				let result = try await page.evaluate("1 + 1")
				#expect(result as? Int == 2)
			}
		}

		@Test("page.evaluate returns a string")
		func evaluateString() async throws {
			try await withPage { page in
				try await page.goto("https://example.com")
				let result = try await page.evaluate("document.title")
				#expect(result as? String == "Example Domain")
			}
		}

		@Test("page.evaluate returns null")
		func evaluateNull() async throws {
			try await withPage { page in
				let result = try await page.evaluate("() => null")
				#expect(result == nil)
			}
		}

		@Test("page.evaluate passes NSNull as JavaScript null")
		func evaluateNSNullArg() async throws {
			try await withPage { page in
				let result = try await page.evaluate("(x) => x === null", arg: NSNull())
				#expect(result as? Bool == true)
			}
		}

		@Test("page.evaluate distinguishes null from undefined")
		func evaluateNullVsUndefined() async throws {
			try await withPage { page in
				// NSNull → null
				let isNull = try await page.evaluate("(x) => x === null", arg: NSNull())
				#expect(isNull as? Bool == true)

				// nil (omitted) → undefined
				let isUndefined = try await page.evaluate("(x) => x === undefined")
				#expect(isUndefined as? Bool == true)
			}
		}

		@Test("page.evaluate preserves default parameters")
		func evaluateDefaultParams() async throws {
			try await withPage { page in
				let result = try await page.evaluate("(x = 1) => x")
				#expect(result as? Int == 1)
			}
		}

		@Test("page.evaluate returns an object")
		func evaluateObject() async throws {
			try await withPage { page in
				let result = try await page.evaluate("() => ({ a: 1, b: 'hello' })")
				let dict = try #require(result as? [String: Any])
				#expect(dict["a"] as? Int == 1)
				#expect(dict["b"] as? String == "hello")
			}
		}

		@Test("page.evaluate returns an array with correct values")
		func evaluateArray() async throws {
			try await withPage { page in
				let result = try await page.evaluate("() => [1, 'two', true]")
				let arr = result as? [Any]
				#expect(arr?.count == 3)
				#expect(arr?[0] as? Int == 1)
				#expect(arr?[1] as? String == "two")
				#expect(arr?[2] as? Bool == true)
			}
		}

		@Test("page.evaluate with argument")
		func evaluateWithArg() async throws {
			try await withPage { page in
				let result = try await page.evaluate("(x) => x * 2", arg: 21)
				#expect(result as? Int == 42)
			}
		}

		@Test("page.evaluate round-trips non-finite doubles")
		func evaluateNonFiniteDoubles() async throws {
			try await withPage { page in
				let nan = try await page.evaluate("(x) => x", arg: Double.nan)
				#expect((nan as? Double)?.isNaN == true)

				let inf = try await page.evaluate("(x) => x", arg: Double.infinity)
				#expect(inf as? Double == .infinity)

				let negInf = try await page.evaluate("(x) => x", arg: -Double.infinity)
				#expect(negInf as? Double == -.infinity)

				let negZero = try await page.evaluate("(x) => x", arg: -0.0)
				let d = try #require(negZero as? Double)
				#expect(d.isZero && d.sign == .minus)
			}
		}

		@Test("page.evaluate with array argument")
		func evaluateWithArrayArg() async throws {
			try await withPage { page in
				let result = try await page.evaluate("(arr) => arr.map(x => x * 2)", arg: [1, 2, 3] as [Any])
				let arr = result as? [Any]
				#expect(arr?.count == 3)
				#expect(arr?[0] as? Int == 2)
				#expect(arr?[1] as? Int == 4)
				#expect(arr?[2] as? Int == 6)
			}
		}

		@Test("page.evaluate round-trips a Date argument")
		func evaluateDateArg() async throws {
			try await withPage { page in
				let date = Date(timeIntervalSince1970: 1_705_312_200) // 2024-01-15T10:30:00Z
				let isDate = try await page.evaluate("(d) => d instanceof Date", arg: date)
				#expect(isDate as? Bool == true)

				let ms = try await page.evaluate("(d) => d.getTime()", arg: date)
				#expect(ms as? Int == 1_705_312_200_000)
			}
		}

		@Test("page.evaluate round-trips a URL argument")
		func evaluateURLArg() async throws {
			try await withPage { page in
				let url = URL(string: "https://example.com/path?q=1")!
				let isURL = try await page.evaluate("(u) => u instanceof URL", arg: url)
				#expect(isURL as? Bool == true)

				let href = try await page.evaluate("(u) => u.href", arg: url)
				#expect(href as? String == "https://example.com/path?q=1")
			}
		}

		@Test("page.evaluate throws invalidArgument on unsupported argument type")
		func evaluateThrowsOnUnsupportedType() async throws {
			try await withPage { page in
				await #expect {
					try await page.evaluate("(x) => x", arg: NSObject())
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}

		@Test("page.evaluate throws invalidArgument on unsupported type nested in array")
		func evaluateThrowsOnNestedUnsupportedType() async throws {
			try await withPage { page in
				await #expect {
					try await page.evaluate("(x) => x", arg: [1, NSObject()] as [Any])
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}

		@Test("page.evaluate returns a Date")
		func evaluateDate() async throws {
			try await withPage { page in
				let result = try await page.evaluate("new Date('2024-01-15T10:30:00.000Z')")
				let date = try #require(result as? Date)

				let calendar = Calendar(identifier: .gregorian)
				let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
				#expect(components.year == 2024)
				#expect(components.month == 1)
				#expect(components.day == 15)
			}
		}

		@Test("page.evaluate returns a URL")
		func evaluateURL() async throws {
			try await withPage { page in
				let result = try await page.evaluate("new URL('https://example.com/path?q=1')")
				let url = try #require(result as? URL)
				#expect(url.host() == "example.com")
				#expect(url.path() == "/path")
			}
		}

		@Test("page.evaluate returns a BigInt that fits in Int")
		func evaluateBigIntSmall() async throws {
			try await withPage { page in
				let result = try await page.evaluate("BigInt(42)")
				#expect(result as? Int == 42)
			}
		}

		@Test("page.evaluate returns a large BigInt as String")
		func evaluateBigIntLarge() async throws {
			try await withPage { page in
				let result = try await page.evaluate("BigInt('99999999999999999999')")
				#expect(result as? String == "99999999999999999999")
			}
		}

		@Test("page.evaluate returns a Uint8Array")
		func evaluateTypedArray() async throws {
			try await withPage { page in
				let result = try await page.evaluate("new Uint8Array([1, 2, 3, 255])")
				let arr = result as? [UInt8]
				#expect(arr == [1, 2, 3, 255])
			}
		}

		@Test("page.evaluate returns a Float64Array")
		func evaluateFloat64Array() async throws {
			try await withPage { page in
				let result = try await page.evaluate("new Float64Array([1.5, 2.5, 3.5])")
				let arr = result as? [Double]
				#expect(arr == [1.5, 2.5, 3.5])
			}
		}

		@Test("page.evaluate returns typed arrays with multi-byte elements")
		func evaluateMultiByteTypedArrays() async throws {
			try await withPage { page in
				let i16 = try await page.evaluate("new Int16Array([1, -2, 32767])")
				#expect(i16 as? [Int16] == [1, -2, 32767])

				let i32 = try await page.evaluate("new Int32Array([1, -2, 2147483647])")
				#expect(i32 as? [Int32] == [1, -2, 2_147_483_647])

				let f32 = try await page.evaluate("new Float32Array([1.5, -2.5])")
				#expect(f32 as? [Float] == [1.5, -2.5])
			}
		}

		@Test("page.evaluate returns a RegExp")
		func evaluateRegExp() async throws {
			try await withPage { page in
				let result = try await page.evaluate("/hello/gi")
				let dict = result as? [String: String]
				#expect(dict?["pattern"] == "hello")
				#expect(dict?["flags"] == "gi")
			}
		}

		// Linux's swift-corelibs-foundation bridges NSMutableDictionary to a Swift
		// dictionary on retrieval, so shared-reference identity (===) is lost.
		@Test("page.evaluate returns shared references correctly", .enabled(if: isApplePlatform))
		func evaluateSharedRef() async throws {
			try await withPage { page in
				let result = try await page.evaluate("""
					() => {
						const shared = { x: 1 };
						return { a: shared, b: shared };
					}
					""")
				let dict = try #require(result as? NSDictionary)
				let a = try #require(dict["a"] as? NSDictionary)
				let b = try #require(dict["b"] as? NSDictionary)
				#expect(a["x"] as? Int == 1)
				#expect(a === b)
			}
		}

		@Test("evaluate serializer sends JSONSerialization's 0/1 as numbers, not booleans")
		func evaluateNumericZeroOne() async throws {
			try await withPage { page in
				let json = Data(#"{"count":0,"flag":1}"#.utf8)
				let parsed = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

				let result = try await page.evaluate("(obj) => typeof obj.count + ',' + typeof obj.flag + ',' + obj.count + ',' + obj.flag", arg: parsed)
				#expect(result as? String == "number,number,0,1")
			}
		}

		@Test("page.evaluate still sends Swift Bool as boolean")
		func evaluateSwiftBool() async throws {
			try await withPage { page in
				let result = try await page.evaluate("(x) => typeof x", arg: true)
				#expect(result as? String == "boolean")

				let result2 = try await page.evaluate("(x) => typeof x", arg: false)
				#expect(result2 as? String == "boolean")
			}
		}

		// On Linux, NSArray subscript bridges elements via _StructBridgeable, breaking
		// ObjectIdentifier-based cycle detection. The depth limit prevents a crash but
		// can't preserve the circular structure.
		@Test("page.evaluate handles circular NSMutableArray argument", .enabled(if: isApplePlatform))
		func evaluateCircularArrayArg() async throws {
			try await withPage { page in
				let a = NSMutableArray(array: [1])
				a.add(a) // a = [1, a]
				let result = try await page.evaluate(
					"(x) => Array.isArray(x) && x.length === 2 && x[0] === 1 && x[1] === x",
					arg: a
				)
				#expect(result as? Bool == true)
			}
		}

		@Test("page.evaluate handles circular NSMutableDictionary argument", .enabled(if: isApplePlatform))
		func evaluateCircularDictArg() async throws {
			try await withPage { page in
				let obj = NSMutableDictionary()
				obj["value"] = 42
				obj["self"] = obj
				let result = try await page.evaluate("(x) => x.value === 42 && x.self === x", arg: obj)
				#expect(result as? Bool == true)
			}
		}


		@Test("page.evaluate preserves shared reference identity in arguments")
		func evaluateSharedRefArg() async throws {
			try await withPage { page in
				let shared = NSMutableDictionary()
				shared["x"] = 1
				let arg: [String: Any] = ["a": shared, "b": shared]
				let result = try await page.evaluate("(obj) => obj.a === obj.b", arg: arg)
				#expect(result as? Bool == true)
			}
		}

		@Test("page.evaluate propagates JavaScript TypeError")
		func evaluateTypeError() async throws {
			try await withPage { page in
				await #expect {
					try await page.evaluate("() => { null.foo }")
				} throws: { error in
					guard case let PlaywrightError.evaluationFailed(msg) = error else { return false }
					return msg.contains("TypeError")
				}
			}
		}

		@Test("page.evaluate propagates JavaScript ReferenceError")
		func evaluateReferenceError() async throws {
			try await withPage { page in
				await #expect {
					try await page.evaluate("() => { undeclaredVariable }")
				} throws: { error in
					guard case let PlaywrightError.evaluationFailed(msg) = error else { return false }
					return msg.contains("ReferenceError")
				}
			}
		}

		@Test("page.evaluate propagates JavaScript SyntaxError")
		func evaluateSyntaxError() async throws {
			try await withPage { page in
				await #expect {
					try await page.evaluate("() => {{{")
				} throws: { error in
					guard case let PlaywrightError.evaluationFailed(msg) = error else { return false }
					return msg.contains("SyntaxError")
				}
			}
		}

		@Test("page.evaluate propagates JavaScript RangeError")
		func evaluateRangeError() async throws {
			try await withPage { page in
				await #expect {
					try await page.evaluate("() => { function f() { f() }; f() }")
				} throws: { error in
					guard case let PlaywrightError.evaluationFailed(msg) = error else { return false }
					return msg.contains("RangeError")
				}
			}
		}

		@Test("type-safe page.evaluate throws invalidArgument on type mismatch")
		func evaluateTypeMismatch() async throws {
			try await withPage { page in
				await #expect {
					let _: Int = try await page.evaluate("'hello'")
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}

		// MARK: - Additional argument/result types

		@Test("page.evaluate with dictionary argument")
		func evaluateWithDictArg() async throws {
			try await withPage { page in
				let dict: [String: Any] = ["key": "value", "num": 42]
				let result = try await page.evaluate("(obj) => obj.key + ':' + obj.num", arg: dict)
				#expect(result as? String == "value:42")
			}
		}

		@Test("page.evaluate returns a bare double (1.5)")
		func evaluateBareDouble() async throws {
			try await withPage { page in
				let result = try await page.evaluate("() => 1.5")
				#expect(result as? Double == 1.5)
			}
		}

		@Test("page.evaluate with empty string argument and return")
		func evaluateEmptyString() async throws {
			try await withPage { page in
				let result = try await page.evaluate("(x) => x", arg: "")
				#expect(result as? String == "")
			}
		}

		@Test("page.evaluate returns a JavaScript Error object")
		func evaluateErrorObject() async throws {
			try await withPage { page in
				let result = try await page.evaluate("""
					() => {
						const e = new Error('test error');
						e.name = 'CustomError';
						return e;
					}
					""")
				let dict = result as? [String: Any]
				#expect(dict?["message"] as? String == "test error")
				#expect(dict?["name"] as? String == "CustomError")
			}
		}

		@Test("page.evaluate returns undefined as nil")
		func evaluateUndefined() async throws {
			try await withPage { page in
				let result = try await page.evaluate("() => {}")
				#expect(result == nil)
			}
		}

		@Test("page.evaluate resolves circular references", .enabled(if: isApplePlatform))
		func evaluateCircularRef() async throws {
			try await withPage { page in
				// Self-referential array: a[0] === a
				let arrayResult = try await page.evaluate("""
					() => { const a = [1]; a.push(a); return a; }
					""")
				let arr = try #require(arrayResult as? [Any])
				#expect(arr.count == 2)
				#expect(arr[0] as? Int == 1)
				// arr[1] is the same array (circular ref) — verify identity is preserved
				let inner = try #require(arr[1] as? NSMutableArray)
				#expect(inner === (arrayResult as AnyObject))

				// Self-referential object: o.self === o
				let objResult = try await page.evaluate("""
					() => { const o = { v: 42 }; o.self = o; return o; }
					""")
				let obj = try #require(objResult as? [String: Any])
				#expect(obj["v"] as? Int == 42)
				let selfRef = try #require(obj["self"] as? NSMutableDictionary)
				#expect(selfRef === (objResult as AnyObject))
			}
		}
	}
}
