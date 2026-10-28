import Foundation
import Synchronization
import Testing
@testable import NativeBusinessApp

// MARK: - HTTP

/// Transport stub that records requests and answers through a handler. Each test owns its own
/// instance, so tests can run in parallel.
final class StubTransport: HTTPTransport {
    typealias Handler = @Sendable (URLRequest, Int) async throws -> (Data, HTTPURLResponse)

    private let handler: Handler
    private let recorded = Mutex<[URLRequest]>([])

    /// - Parameter handler: receives the request and its zero-based call index.
    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    var requests: [URLRequest] { recorded.withLock { $0 } }
    var callCount: Int { recorded.withLock { $0.count } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let index = recorded.withLock { requests in
            requests.append(request)
            return requests.count - 1
        }
        return try await handler(request, index)
    }
}

enum HTTPStub {
    static func response(
        for request: URLRequest,
        status: Int = 200,
        json: String = "{}",
        headers: [String: String] = ["Content-Type": "application/json"]
    ) -> (Data, HTTPURLResponse) {
        let url = request.url ?? URL(filePath: "/")
        // HTTPURLResponse's initialiser only fails for invalid HTTP versions.
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        return (Data(json.utf8), response)
    }
}

enum TestConfig {
    static let baseURL = URL(string: "https://api.test.invalid/v1")!

    static func api(retry: RetryPolicy = .disabled) -> APIConfiguration {
        APIConfiguration(baseURL: baseURL, requestTimeout: 10, retryPolicy: retry)
    }

    static func httpClient(transport: StubTransport, retry: RetryPolicy = .disabled) -> HTTPClient {
        HTTPClient(configuration: api(retry: retry), transport: transport, sleep: { _ in })
    }

    static func appConfiguration(baseURL: URL = baseURL) -> AppConfiguration {
        AppConfiguration(
            environment: .development, apiBaseURL: baseURL, requestTimeout: 10, loginIdentifierKind: .email,
            passwordResetURL: nil, displayName: "Business", version: "1.0 (1)"
        )
    }
}

struct SampleResponse: Codable, Equatable, Sendable {
    let id: String
    let value: Int
}

// MARK: - Fixtures

enum Fixtures {
    static let user = User(id: "user-123", name: "Example User", email: "user@example.com")
    static let tokens = AuthTokens(accessToken: "access-1", refreshToken: "refresh-1", expiresAt: nil)
    static let refreshedTokens = AuthTokens(accessToken: "access-2", refreshToken: "refresh-2", expiresAt: nil)

    static let referenceDate = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01T00:00:00Z

    static func activity(id: String, hoursAgo: Double = 1) -> ActivityItem {
        ActivityItem(id: id, title: "Item \(id)", detail: nil, category: "General",
                     occurredAt: referenceDate.addingTimeInterval(-hoursAgo * 3_600), status: .completed, amount: nil)
    }

    static let metric = Metric(id: "revenue", title: "Revenue", value: .count(10), changePercent: 1)

    static func notification(id: String, isRead: Bool = false) -> AppNotification {
        AppNotification(id: id, title: "Title \(id)", message: "Message", createdAt: referenceDate, isRead: isRead, category: nil)
    }
}

// MARK: - Authentication

final class MockTokenRefresher: TokenRefreshing {
    private struct State {
        var result: Result<AuthTokens, any Error>
        var calls: [String] = []
    }

    private let state: Mutex<State>
    private let delay: Duration

    init(result: Result<AuthTokens, any Error> = .success(Fixtures.refreshedTokens), delay: Duration = .zero) {
        state = Mutex(State(result: result))
        self.delay = delay
    }

    var calls: [String] { state.withLock { $0.calls } }

    func setResult(_ result: Result<AuthTokens, any Error>) {
        state.withLock { $0.result = result }
    }

    func refreshTokens(using refreshToken: String) async throws -> AuthTokens {
        let result = state.withLock { state in
            state.calls.append(refreshToken)
            return state.result
        }
        if delay > .zero { try await Task.sleep(for: delay) }
        return try result.get()
    }
}

final class MockAuthRepository: AuthRepository {
    struct State {
        var loginResult: Result<AuthSession, any Error> = .success(AuthSession(tokens: Fixtures.tokens, user: Fixtures.user))
        var currentUserResult: Result<User, any Error> = .success(Fixtures.user)
        var currentUserDelay: Duration = .zero
        var loginCalls: [String] = []
        var currentUserCalls = 0
        var logoutCalls: [String?] = []
    }

    let state = Mutex(State())

    func update(_ body: (inout State) -> Void) {
        state.withLock { body(&$0) }
    }

    func login(identifier: String, password: String) async throws -> AuthSession {
        let result = state.withLock { state in
            state.loginCalls.append(identifier)
            return state.loginResult
        }
        return try result.get()
    }

    func currentUser() async throws -> User {
        let (result, delay) = state.withLock { state in
            state.currentUserCalls += 1
            return (state.currentUserResult, state.currentUserDelay)
        }
        if delay > .zero { try await Task.sleep(for: delay) }
        return try result.get()
    }

    func logout(refreshToken: String?) async throws {
        state.withLock { $0.logoutCalls.append(refreshToken) }
    }
}

@MainActor
final class MockAuthenticator: LoginAuthenticating {
    var error: (any Error)?
    var delay: Duration = .zero
    private(set) var calls: [(identifier: String, password: String)] = []

    func login(identifier: String, password: String) async throws {
        calls.append((identifier, password))
        if delay > .zero { try await Task.sleep(for: delay) }
        if let error { throw error }
    }
}

@MainActor
final class MockSessionTerminator: SessionTerminating {
    private(set) var logoutCount = 0
    func logout() async { logoutCount += 1 }
}

// MARK: - Feature repositories

final class MockDashboardRepository: DashboardRepository {
    struct State {
        var summary: Result<DashboardSummary, any Error> = .success(DashboardSummary(metrics: [Fixtures.metric], generatedAt: nil))
        var activity: Result<[ActivityItem], any Error> = .success([Fixtures.activity(id: "a1")])
    }

    let state = Mutex(State())

    func update(_ body: (inout State) -> Void) {
        state.withLock { body(&$0) }
    }

    func fetchSummary() async throws -> DashboardSummary {
        try state.withLock { $0.summary }.get()
    }

    func fetchRecentActivity(limit: Int) async throws -> [ActivityItem] {
        try state.withLock { $0.activity }.get()
    }
}

final class MockNotificationsRepository: NotificationsRepository {
    struct State {
        var notifications: Result<[AppNotification], any Error> = .success([])
        var markResult: Result<Void, any Error> = .success(())
        var markedIDs: [String] = []
        var markAllCount = 0
    }

    let state = Mutex(State())

    func update(_ body: (inout State) -> Void) {
        state.withLock { body(&$0) }
    }

    func fetchNotifications() async throws -> [AppNotification] {
        try state.withLock { $0.notifications }.get()
    }

    func markAsRead(id: String) async throws {
        try state.withLock { state in
            state.markedIDs.append(id)
            return state.markResult
        }.get()
    }

    func markAllAsRead() async throws {
        try state.withLock { state in
            state.markAllCount += 1
            return state.markResult
        }.get()
    }
}

// MARK: - Async helpers

/// Polls `condition` on the main actor until it is true or the timeout elapses.
@MainActor
func waitUntil(timeout: Duration = .seconds(3), _ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        if clock.now >= deadline {
            Issue.record("Timed out waiting for condition", sourceLocation: sourceLocation)
            return
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
}
