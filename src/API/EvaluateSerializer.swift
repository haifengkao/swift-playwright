import Foundation

/// Serializes and deserializes values for Playwright's `evaluate` protocol.
///
/// Playwright uses a tagged-union format for passing values between the client
/// and server. This serializer converts Swift values to that format and back.
enum EvaluateSerializer {
	/// Serializes a Swift value into Playwright's tagged-union format.
	///
	/// Format: `{"value": <tagged>, "handles": []}`
	///
	/// - Throws: `PlaywrightError.invalidArgument` if the value contains an unsupported type.
	static func serializeArgument(_ value: Any?) throws -> [String: Any] {
		return try [
			"handles": [] as [Any],
			"value": serializeValue(value, visitor: VisitorInfo()),
		]
	}

	/// Parses a tagged-union result from the server into a Swift value.
	static func parseResult(_ value: Any?) -> Any? {
		guard let dict = value as? [String: Any] else { return nil }

		var refs: [Int: Any] = [:]
		return parseValue(dict, refs: &refs)
	}

	// MARK: - Serialization

	/// Tracks collections by identity during serialization to preserve shared
	/// references and break circular references.
	///
	/// Uses `ObjectIdentifier` on the `AnyObject`-bridged value. For reference
	/// types (`NSArray`, `NSMutableDictionary`, etc.) this is a stable identity —
	/// the same object always resolves to the same ID. For value-type Swift
	/// Arrays/Dicts, each bridge creates a fresh identity, so they always
	/// register as new — correct since value types can't be circular or shared.
	private final class VisitorInfo {
		private var counter = 0
		private var visited: [ObjectIdentifier: Int] = [:]

		func visit(_ obj: AnyObject) -> (alreadyVisited: Bool, id: Int) {
			let key = ObjectIdentifier(obj)

			if let existing = visited[key] {
				return (true, existing)
			}

			counter += 1
			visited[key] = counter
			return (false, counter)
		}
	}

	private static func serializeValue(_ value: Any?, visitor: VisitorInfo) throws -> [String: Any] {
		guard let value else { return ["v": "undefined"] }

		// Bool, Int, and Double all bridge to NSNumber when erased to Any.
		// Check Bool first: on macOS, NSNumber(0/1) ambiguously matches `as? Bool`,
		// so we use CFBooleanGetTypeID to distinguish. On Linux, swift-corelibs-foundation
		// preserves the Bool type, so `type(of:) == Bool.self` is sufficient.
		if let number = value as? NSNumber {
			#if canImport(Darwin)
			if CFGetTypeID(number) == CFBooleanGetTypeID() {
				return ["b": number.boolValue]
			}
			#else
			if type(of: value) == Bool.self {
				return ["b": number.boolValue]
			}
			#endif
			if let n = value as? Int { return ["n": n] }
			let d = number.doubleValue
			if d.isNaN { return ["v": "NaN"] }
			if d == .infinity { return ["v": "Infinity"] }
			if d == -.infinity { return ["v": "-Infinity"] }
			if d.isZero, d.sign == .minus { return ["v": "-0"] }
			return ["n": d]
		}

		// Check NSArray/NSDictionary identity *before* bridging to [Any]/[String: Any],
		// so we can detect shared/circular references via ObjectIdentifier.
		// Note: circular NS containers are unsupported on Linux (Foundation crashes internally).
		if let nsArr = value as? NSArray {
			let (alreadyVisited, id) = visitor.visit(nsArr)
			if alreadyVisited { return ["ref": id] }
			return try ["a": (0..<nsArr.count).map { try serializeValue(nsArr[$0], visitor: visitor) }, "id": id]
		}
		if let nsDict = value as? NSDictionary {
			let (alreadyVisited, id) = visitor.visit(nsDict)
			if alreadyVisited { return ["ref": id] }
			let serialized: [[String: Any]] = try nsDict.allKeys.map { key in
				guard let k = key as? String else {
					throw PlaywrightError.invalidArgument("Dictionary with non-String keys is not supported")
				}
				return try ["k": k, "v": serializeValue(nsDict[key], visitor: visitor)] as [String: Any]
			}
			return ["o": serialized, "id": id]
		}

		switch value {
			case is NSNull: return ["v": "null"]
			case let s as String: return ["s": s]
			case let url as URL: return ["u": url.absoluteString]
			case let date as Date: return ["d": iso8601.string(from: date)]
			case let arr as [Any]:
				return try ["a": arr.map { try serializeValue($0, visitor: visitor) }, "id": 0]
			case let dict as [String: Any]:
				let serialized = try dict.map { k, v in
					try ["k": k, "v": serializeValue(v, visitor: visitor)] as [String: Any]
				}
				return ["o": serialized, "id": 0]
			default:
				throw PlaywrightError.invalidArgument("Unsupported type of argument: \(type(of: value))")
		}
	}

	// MARK: - Deserialization

	private nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
		let f = ISO8601DateFormatter()
		f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return f
	}()

	private static func parseValue(_ dict: [String: Any], refs: inout [Int: Any]) -> Any? {
		if let v = dict["v"] as? String {
			switch v {
				case "-0": return -0.0
				case "NaN": return Double.nan
				case "null", "undefined": return nil
				case "Infinity": return Double.infinity
				case "-Infinity": return -Double.infinity
				default: return nil
			}
		}

		if let n = dict["n"] as? Int { return n }
		if let b = dict["b"] as? Bool { return b }
		if let s = dict["s"] as? String { return s }
		if let n = dict["n"] as? Double { return n }
		if let u = dict["u"] as? String { return URL(string: u) }
		if let d = dict["d"] as? String { return iso8601.date(from: d) }

		// BigInt → Int if it fits, otherwise String
		if let bi = dict["bi"] as? String {
			return Int(bi) ?? bi
		}

		// RegExp → dictionary with pattern and flags
		if let r = dict["r"] as? [String: Any] {
			return [
				"pattern": r["p"] as? String ?? "",
				"flags": r["f"] as? String ?? "",
			]
		}

		// Errors
		if let e = dict["e"] as? [String: Any] {
			return [
				"name": e["n"] as? String,
				"stack": e["s"] as? String,
				"message": e["m"] as? String,
			].compactMapValues { $0 }
		}

		// TypedArray → native Swift typed array
		if let ta = dict["ta"] as? [String: Any],
		   let b64 = ta["b"] as? String,
		   let kind = ta["k"] as? String,
		   let data = Data(base64Encoded: b64)
		{
			return decodeTypedArray(data: data, kind: kind)
		}

		// Shared/circular reference
		if let ref = dict["ref"] as? Int {
			return refs[ref]
		}

		// Arrays and objects use NSMutable* reference types so that circular
		// refs (e.g. `const a = []; a.push(a); return a`) resolve correctly —
		// we register the container in `refs` *before* walking its children.
		// NSMutableArray/NSMutableDictionary bridge to [Any]/[String: Any] via `as?`.
		if let a = dict["a"] as? [[String: Any]] {
			let result = NSMutableArray()
			if let id = dict["id"] as? Int { refs[id] = result }

			for entry in a {
				result.add((parseValue(entry, refs: &refs) ?? NSNull()) as Any)
			}

			return result
		}

		// Objects also support circular refs, but their children are key-value pairs instead of array entries.
		if let o = dict["o"] as? [[String: Any]] {
			let result = NSMutableDictionary()
			if let id = dict["id"] as? Int { refs[id] = result }

			for entry in o {
				guard let k = entry["k"] as? String, let v = entry["v"] as? [String: Any] else { continue }
				result[k] = (parseValue(v, refs: &refs) ?? NSNull()) as Any
			}

			return result
		}

		return nil
	}

	private static func decodeTypedArray(data: Data, kind: String) -> Any {
		switch kind {
			case "i8": return data.withUnsafeBytes { Array($0.bindMemory(to: Int8.self)) }
			case "i16": return data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
			case "i32": return data.withUnsafeBytes { Array($0.bindMemory(to: Int32.self)) }
			case "f32": return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
			case "f64": return data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
			case "bi64": return data.withUnsafeBytes { Array($0.bindMemory(to: Int64.self)) }
			case "ui16": return data.withUnsafeBytes { Array($0.bindMemory(to: UInt16.self)) }
			case "ui32": return data.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }
			case "bui64": return data.withUnsafeBytes { Array($0.bindMemory(to: UInt64.self)) }
			case "ui8", "ui8c": return data.withUnsafeBytes { Array($0.bindMemory(to: UInt8.self)) }
			default: return Array(data)
		}
	}
}
