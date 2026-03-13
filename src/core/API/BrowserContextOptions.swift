import Foundation

// MARK: - Supporting Types for Browser Context Options

/// HTTP basic authentication credentials.
///
/// See: https://playwright.dev/docs/api/class-browser#browser-new-context-option-http-credentials
public struct HttpCredentials: Sendable {
	public var username: String
	public var password: String

	public init(username: String, password: String) {
		self.username = username
		self.password = password
	}

	func toParams() -> [String: Any] {
		["username": username, "password": password]
	}
}

/// Geographic location to emulate.
///
/// See: https://playwright.dev/docs/api/class-browser#browser-new-context-option-geolocation
public struct Geolocation: Sendable {
	/// Latitude in degrees, between -90 and 90.
	public var latitude: Double

	/// Longitude in degrees, between -180 and 180.
	public var longitude: Double

	/// Non-negative accuracy in meters. Defaults to 0.
	public var accuracy: Double?

	public init(latitude: Double, longitude: Double, accuracy: Double? = nil) {
		self.latitude = latitude
		self.accuracy = accuracy
		self.longitude = longitude
	}

	func toParams() -> [String: Any] {
		var params: [String: Any] = ["latitude": latitude, "longitude": longitude]
		if let accuracy { params["accuracy"] = accuracy }
		return params
	}
}

/// Color scheme to emulate.
///
/// See: https://playwright.dev/docs/api/class-browser#browser-new-context-option-color-scheme
public enum ColorScheme: String, Sendable {
	case light, dark
	case noPreference = "no-preference"
}
