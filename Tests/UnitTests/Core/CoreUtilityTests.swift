import Foundation
import Testing
@testable import NativeBusinessApp

@Suite("Log redaction")
struct LogRedactorTests {
    @Test func redactsSensitiveHeaders() {
        let redacted = LogRedactor.redact(headers: ["Authorization": "Bearer abc", "cookie": "s=1", "Accept": "application/json"])
        #expect(redacted["Authorization"] == LogRedactor.placeholder)
        #expect(redacted["cookie"] == LogRedactor.placeholder)
        #expect(redacted["Accept"] == "application/json")
    }

    @Test func redactsSensitiveBodyFieldsRecursively() {
        let body = Data(#"{"email":"a@b.co","password":"hunter2","nested":{"refresh_token":"r","items":[{"accessToken":"t"}]}}"#.utf8)
        let output = LogRedactor.redact(body: body)
        for secret in ["hunter2", "\"r\"", "\"t\""] {
            #expect(!output.contains(secret))
        }
        #expect(output.contains("a@b.co"))
        #expect(output.contains(LogRedactor.placeholder))
    }

    @Test func summarisesNonJSONBodies() {
        #expect(LogRedactor.redact(body: Data("password=hunter2".utf8)) == "<16 bytes, non-JSON>")
        #expect(LogRedactor.redact(body: nil) == "<empty>")
    }

    @Test func redactsURLCredentialsAndSensitiveQueryItems() {
        let url = URL(string: "https://user:pass@api.example.com/x?token=abc&page=2")
        let output = LogRedactor.redact(url: url)
        #expect(!output.contains("pass@"))
        #expect(!output.contains("abc"))
        #expect(output.contains("page=2"))
    }

    @Test func requestDescriptionNeverContainsSecrets() throws {
        var request = URLRequest(url: try #require(URL(string: "https://api.example.com/auth/login")))
        request.httpMethod = "POST"
        request.setValue("Bearer secret-token", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(#"{"email":"a@b.co","password":"secret-password"}"#.utf8)
        let description = LogRedactor.describe(request, includeBody: true)
        #expect(!description.contains("secret"))
        #expect(description.hasPrefix("POST https://api.example.com/auth/login"))
    }
}

@Suite("User-facing error presentation")
struct UserFacingErrorTests {
    @Test(arguments: [
        (APIError.noConnection as any Error, UserFacingError.Kind.offline, true),
        (APIError.cannotReachServer, .serverUnreachable, true),
        (APIError.timeout, .timeout, true),
        (APIError.unauthorized, .sessionExpired, false),
        (AuthError.sessionExpired, .sessionExpired, false),
        (AuthError.invalidCredentials, .invalidCredentials, false),
        (APIError.forbidden, .accessDenied, false),
        (APIError.rateLimited(retryAfter: 3), .rateLimited, true),
        (APIError.server(statusCode: 502), .server, true),
        (APIError.decodingFailed("X"), .server, true),
        (APIError.keychain(.invalidItemData), .storage, true),
        (KeychainError.encodingFailed, .storage, true),
        (APIError.invalidConfiguration("x"), .configuration, false),
        (URLError(.notConnectedToInternet), .offline, true),
    ])
    func mapsErrors(error: any Error, kind: UserFacingError.Kind, retryable: Bool) {
        let presented = UserFacingError(error)
        #expect(presented.kind == kind)
        #expect(presented.isRetryable == retryable)
        #expect(!presented.message.isEmpty)
    }

    @Test func messagesDoNotLeakImplementationDetails() {
        let presented = UserFacingError(APIError.decodingFailed("DashboardSummaryDTO"))
        #expect(!presented.message.contains("DTO"))
        #expect(!UserFacingError(APIError.server(statusCode: 503)).message.contains("503"))
    }

    @Test func detectsCancellation() {
        #expect(CancellationError().isCancellation)
        #expect(APIError.cancelled.isCancellation)
        #expect(URLError(.cancelled).isCancellation)
        #expect(!APIError.timeout.isCancellation)
    }
}

@Suite("App configuration")
struct AppConfigurationTests {
    private func info(_ overrides: [String: String] = [:]) -> [String: Any] {
        var info: [String: Any] = [
            "AppEnvironment": "production", "APIBaseURL": "https://api.mycompany.io/v1", "APITimeoutSeconds": "20",
            "LoginIdentifierKind": "username", "PasswordResetURL": "", "CFBundleShortVersionString": "1.2", "CFBundleVersion": "7",
        ]
        overrides.forEach { info[$0.key] = $0.value }
        return info
    }

    @Test func loadsValidConfiguration() throws {
        let configuration = try AppConfiguration.load(from: info())
        #expect(configuration.environment == .production)
        #expect(configuration.apiBaseURL.absoluteString == "https://api.mycompany.io/v1")
        #expect(configuration.requestTimeout == 20)
        #expect(configuration.loginIdentifierKind == .username)
        #expect(configuration.passwordResetURL == nil)
        #expect(configuration.version == "1.2 (7)")
        #expect(!configuration.usesPlaceholderBaseURL)
    }

    @Test func rejectsPlaceholderURLOutsideDevelopment() {
        #expect(throws: ConfigurationError.placeholderBaseURL(.production)) {
            try AppConfiguration.load(from: info(["APIBaseURL": "https://api.example.com"]))
        }
        #expect(throws: ConfigurationError.placeholderBaseURL(.staging)) {
            try AppConfiguration.load(from: info(["AppEnvironment": "staging", "APIBaseURL": "https://staging-api.example.com"]))
        }
    }

    @Test func allowsPlaceholderInDevelopmentButFlagsIt() throws {
        let configuration = try AppConfiguration.load(from: info(["AppEnvironment": "development", "APIBaseURL": "https://dev-api.example.com"]))
        #expect(configuration.usesPlaceholderBaseURL)
    }

    @Test func requiresHTTPSExceptLocalhostInDevelopment() throws {
        #expect(throws: ConfigurationError.insecureBaseURL) {
            try AppConfiguration.load(from: info(["APIBaseURL": "http://api.mycompany.io"]))
        }
        #expect(throws: ConfigurationError.insecureBaseURL) {
            try AppConfiguration.load(from: info(["APIBaseURL": "http://localhost:8080"]))
        }
        _ = try AppConfiguration.load(from: info(["AppEnvironment": "development", "APIBaseURL": "http://localhost:8080"]))
    }

    @Test func reportsMissingAndInvalidValues() {
        #expect(throws: ConfigurationError.missingValue(key: "API_BASE_URL")) {
            try AppConfiguration.load(from: info(["APIBaseURL": "$(API_BASE_URL)"]))
        }
        #expect(throws: ConfigurationError.invalidValue(key: "API_TIMEOUT_SECONDS")) {
            try AppConfiguration.load(from: info(["APITimeoutSeconds": "0"]))
        }
        #expect(throws: ConfigurationError.invalidValue(key: "APP_ENVIRONMENT")) {
            try AppConfiguration.load(from: info(["AppEnvironment": "qa"]))
        }
        #expect(throws: ConfigurationError.invalidBaseURL) {
            try AppConfiguration.load(from: info(["APIBaseURL": "not a url"]))
        }
    }

    @Test func bundledConfigurationIsValidForDevelopment() throws {
        // The test host is built with the Debug (development) configuration.
        let configuration = try AppConfiguration.load(from: Bundle.main.infoDictionary ?? [:])
        #expect(configuration.environment == .development)
    }
}

@Suite("Formatting")
struct AppFormattersTests {
    private let formatters = AppFormatters(
        locale: Locale(identifier: "en_US"),
        timeZone: TimeZone(identifier: "UTC")!,
        now: { Fixtures.referenceDate }
    )

    @Test func formatsMetricValues() {
        #expect(formatters.string(for: .count(1284)) == "1,284")
        #expect(formatters.string(for: .currency(Decimal(string: "48250.75")!, currencyCode: "USD")) == "$48,250.75")
        #expect(formatters.string(for: .percentage(0.942)) == "94.2%")
        #expect(formatters.string(for: .number(3.14159)) == "3.14")
    }

    @Test func formatsSignedChange() {
        #expect(formatters.change(4.2) == "+4.2%")
        #expect(formatters.change(-12.5) == "-12.5%")
    }

    @Test func formatsRelativeAndAbsoluteTimestamps() {
        #expect(formatters.timestamp(Fixtures.referenceDate.addingTimeInterval(-20)) == "Just now")
        // The exact abbreviation ("2h ago", "2 hr. ago") is defined by the OS, so only its shape is asserted.
        let relative = formatters.timestamp(Fixtures.referenceDate.addingTimeInterval(-2 * 3_600))
        #expect(relative.contains("2") && relative.contains("ago"))
        // Older dates are absolute. ICU separates "AM" with a narrow no-break space, so compare the parts.
        let absolute = formatters.timestamp(Fixtures.referenceDate.addingTimeInterval(-30 * 86_400))
        #expect(absolute.hasPrefix("Dec 2, 2025"))
        #expect(absolute.contains("12:00"))
    }

    @Test func formatsDateWithYear() {
        #expect(formatters.date(Fixtures.referenceDate) == "Jan 1, 2026")
    }

    @Test func greetingFollowsTimeOfDay() {
        let morning = AppFormatters(locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "UTC")!,
                                    now: { Fixtures.referenceDate.addingTimeInterval(9 * 3_600) })
        #expect(morning.greeting() == "Good morning")
        #expect(formatters.greeting() == "Good evening")
    }

    @Test func userInitials() {
        #expect(User(id: "1", name: "Example User", email: nil).initials == "EU")
        #expect(User(id: "1", name: "cher", email: nil).initials == "C")
        #expect(User(id: "1", name: "  ", email: nil).initials == "?")
    }
}
