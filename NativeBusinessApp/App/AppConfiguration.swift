import Foundation

enum AppEnvironment: String, Sendable, CaseIterable {
    case development
    case staging
    case production

    var displayName: String {
        switch self {
        case .development: String(localized: "Development")
        case .staging: String(localized: "Staging")
        case .production: String(localized: "Production")
        }
    }
}

/// Configuration problems detected at launch. Messages name the setting, never a secret.
enum ConfigurationError: Error, Equatable, Sendable {
    case missingValue(key: String)
    case invalidValue(key: String)
    case invalidBaseURL
    case insecureBaseURL
    case placeholderBaseURL(AppEnvironment)

    var message: String {
        switch self {
        case .missingValue(let key):
            "The build setting for \(key) is missing."
        case .invalidValue(let key):
            "The build setting for \(key) has an unsupported value."
        case .invalidBaseURL:
            "API_BASE_URL is not a valid absolute URL."
        case .insecureBaseURL:
            "API_BASE_URL must use HTTPS. Plain HTTP is accepted only for localhost in development."
        case .placeholderBaseURL(let environment):
            "API_BASE_URL is still a placeholder (example.com) in the \(environment.rawValue) configuration. Set the real server URL in Config/\(environment == .staging ? "Staging" : "Production").xcconfig."
        }
    }
}

/// Typed application configuration, read from Info.plist values injected by Config/*.xcconfig.
///
/// The configuration contains no secrets. Anything bundled with an app can be extracted, so
/// server-side credentials must never be added here.
struct AppConfiguration: Equatable, Sendable {
    let environment: AppEnvironment
    let apiBaseURL: URL
    let requestTimeout: TimeInterval
    let loginIdentifierKind: LoginIdentifierKind
    let passwordResetURL: URL?
    let displayName: String
    let version: String

    enum Key {
        static let environment = "AppEnvironment"
        static let baseURL = "APIBaseURL"
        static let timeout = "APITimeoutSeconds"
        static let loginIdentifierKind = "LoginIdentifierKind"
        static let passwordResetURL = "PasswordResetURL"
    }

    var usesPlaceholderBaseURL: Bool {
        Self.isPlaceholderHost(apiBaseURL.host())
    }

    var apiConfiguration: APIConfiguration {
        APIConfiguration(baseURL: apiBaseURL, requestTimeout: requestTimeout)
    }

    static func load(from info: [String: Any]) throws(ConfigurationError) -> AppConfiguration {
        func string(_ key: String) -> String? {
            guard let value = (info[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty, !value.hasPrefix("$(") else { return nil }
            return value
        }

        guard let environmentValue = string(Key.environment) else { throw .missingValue(key: "APP_ENVIRONMENT") }
        guard let environment = AppEnvironment(rawValue: environmentValue.lowercased()) else {
            throw .invalidValue(key: "APP_ENVIRONMENT")
        }

        guard let baseURLString = string(Key.baseURL) else { throw .missingValue(key: "API_BASE_URL") }
        guard let baseURL = URL(string: baseURLString), let scheme = baseURL.scheme?.lowercased(),
              let host = baseURL.host(), !host.isEmpty, baseURL.query() == nil else {
            throw .invalidBaseURL
        }
        switch scheme {
        case "https":
            break
        case "http" where environment == .development && ["localhost", "127.0.0.1", "::1"].contains(host.lowercased()):
            break
        default:
            throw .insecureBaseURL
        }
        if environment != .development, isPlaceholderHost(host) {
            throw .placeholderBaseURL(environment)
        }

        var timeout: TimeInterval = 30
        if let timeoutString = string(Key.timeout) {
            guard let value = TimeInterval(timeoutString), (1...120).contains(value) else {
                throw .invalidValue(key: "API_TIMEOUT_SECONDS")
            }
            timeout = value
        }

        var identifierKind = LoginIdentifierKind.email
        if let kindString = string(Key.loginIdentifierKind) {
            guard let kind = LoginIdentifierKind(rawValue: kindString.lowercased()) else {
                throw .invalidValue(key: "LOGIN_IDENTIFIER_KIND")
            }
            identifierKind = kind
        }

        var passwordResetURL: URL?
        if let resetString = string(Key.passwordResetURL) {
            guard let url = URL(string: resetString), url.scheme?.lowercased() == "https" else {
                throw .invalidValue(key: "PASSWORD_RESET_URL")
            }
            passwordResetURL = url
        }

        let shortVersion = info["CFBundleShortVersionString"] as? String ?? "0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        let displayName = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? "Business"

        return AppConfiguration(
            environment: environment,
            apiBaseURL: baseURL,
            requestTimeout: timeout,
            loginIdentifierKind: identifierKind,
            passwordResetURL: passwordResetURL,
            displayName: displayName,
            version: "\(shortVersion) (\(build))"
        )
    }

    /// Reserved example domains (RFC 2606 / RFC 6761) that must never be treated as a real backend.
    static func isPlaceholderHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return true }
        let placeholderDomains = ["example.com", "example.org", "example.net"]
        let placeholderTLDs = [".example", ".invalid", ".test"]
        return placeholderDomains.contains { host == $0 || host.hasSuffix(".\($0)") }
            || placeholderTLDs.contains { host.hasSuffix($0) }
    }
}
