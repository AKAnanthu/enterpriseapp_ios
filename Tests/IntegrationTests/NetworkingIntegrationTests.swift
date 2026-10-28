import Foundation
import Synchronization
import Testing
@testable import NativeBusinessApp

/// End-to-end flows through the composition root and a real `URLSession`, with responses served by
/// `StubURLProtocol`. No live server is contacted.
@MainActor
@Suite("Networking integration (URLSession + URLProtocol)")
struct NetworkingIntegrationTests {
    private let host = "integration-\(UUID().uuidString.lowercased()).test"

    private func makeContainer(tokenStore: InMemoryTokenStore = InMemoryTokenStore()) throws -> AppContainer {
        let baseURL = try #require(URL(string: "https://\(host)/v1"))
        let sessionConfiguration = URLSessionConfiguration.api(timeout: 5)
        sessionConfiguration.protocolClasses = [StubURLProtocol.self]
        return AppContainer(
            configuration: TestConfig.appConfiguration(baseURL: baseURL),
            transport: URLSession(configuration: sessionConfiguration),
            tokenStore: tokenStore
        )
    }

    @Test func loginThenLoadDashboard() async throws {
        let seenAuthorization = Mutex<[String: String]>([:])
        StubURLProtocol.register(host: host) { request, body in
            let path = request.url?.path() ?? ""
            seenAuthorization.withLock { $0[path] = request.value(forHTTPHeaderField: "Authorization") ?? "none" }
            switch path {
            case "/v1/auth/login":
                let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
                guard json?["email"] == "user@example.com", json?["password"] == "correct horse" else {
                    return (401, #"{"error":"invalid_credentials"}"#)
                }
                return (200, #"{"accessToken":"at-1","refreshToken":"rt-1","expiresIn":900,"tokenType":"Bearer","user":{"id":"u1","name":"Example User","email":"user@example.com"}}"#)
            case "/v1/dashboard/summary":
                return (200, #"{"metrics":[{"id":"tx","title":"Transactions","value":12,"format":"count"}]}"#)
            case "/v1/dashboard/activity":
                return (200, #"{"items":[]}"#)
            default:
                return (404, "{}")
            }
        }
        defer { StubURLProtocol.unregister(host: host) }

        let container = try makeContainer()
        await container.authManager.restoreSession()
        #expect(container.coordinator.route == .login(nil))

        await #expect(throws: AuthError.invalidCredentials) {
            try await container.authManager.login(identifier: "user@example.com", password: "wrong")
        }
        try await container.authManager.login(identifier: "user@example.com", password: "correct horse")
        #expect(container.coordinator.route == .main(User(id: "u1", name: "Example User", email: "user@example.com")))

        let home = container.makeHomeViewModel()
        await home.load()
        #expect(home.metrics.value?.first?.value == .count(12))
        #expect(home.activity == .empty)

        let headers = seenAuthorization.withLock { $0 }
        #expect(headers["/v1/auth/login"] == "none")
        #expect(headers["/v1/dashboard/summary"] == "Bearer at-1")
    }

    @Test func expiredAccessTokenIsRefreshedTransparently() async throws {
        let refreshCount = Mutex(0)
        StubURLProtocol.register(host: host) { request, _ in
            switch (request.url?.path() ?? "", request.value(forHTTPHeaderField: "Authorization")) {
            case ("/v1/auth/refresh", _):
                refreshCount.withLock { $0 += 1 }
                return (200, #"{"accessToken":"at-new","refreshToken":"rt-new","expiresIn":900}"#)
            case ("/v1/auth/me", "Bearer at-new"):
                return (200, #"{"id":"u1","name":"Example User"}"#)
            case ("/v1/auth/me", _):
                return (401, "{}")
            default:
                return (404, "{}")
            }
        }
        defer { StubURLProtocol.unregister(host: host) }

        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "at-old", refreshToken: "rt-old", expiresAt: nil))
        let container = try makeContainer(tokenStore: store)
        await container.authManager.restoreSession()

        #expect(container.authManager.state.user?.id == "u1")
        #expect(refreshCount.withLock { $0 } == 1)
        #expect(try store.load()?.accessToken == "at-new")
    }

    @Test func revokedRefreshTokenExpiresSessionOnLaunch() async throws {
        StubURLProtocol.register(host: host) { request, _ in
            request.url?.path() == "/v1/auth/refresh" ? (401, #"{"error":"invalid_grant"}"#) : (401, "{}")
        }
        defer { StubURLProtocol.unregister(host: host) }

        let store = InMemoryTokenStore(tokens: Fixtures.tokens)
        let container = try makeContainer(tokenStore: store)
        await container.authManager.restoreSession()

        #expect(container.coordinator.route == .login(.sessionExpired))
        #expect(try store.load() == nil)
    }

    @Test func serverErrorsSurfaceAsSectionFailures() async throws {
        StubURLProtocol.register(host: host) { request, _ in
            request.url?.path() == "/v1/dashboard/summary" ? (500, "{}") : (200, #"{"items":[]}"#)
        }
        defer { StubURLProtocol.unregister(host: host) }

        let container = try makeContainer(tokenStore: InMemoryTokenStore(tokens: Fixtures.tokens))
        let home = container.makeHomeViewModel()
        await home.load()
        #expect(home.metrics.error?.kind == .server)
        #expect(home.activity == .empty)
    }
}

/// Runs the DEBUG demo backend through the full stack, as the UI tests do.
@MainActor
@Suite("Demo backend integration")
struct DemoBackendIntegrationTests {
    private func makeContainer(_ scenario: MockScenario) -> AppContainer {
        AppContainer(
            configuration: TestConfig.appConfiguration(),
            transport: MockBackendTransport(scenario: scenario, latency: .zero),
            tokenStore: InMemoryTokenStore()
        )
    }

    @Test func fullSessionLifecycle() async throws {
        let container = makeContainer(.standard)
        await container.authManager.restoreSession()

        await #expect(throws: AuthError.invalidCredentials) {
            try await container.authManager.login(identifier: "a@b.co", password: MockBackendTransport.rejectedPassword)
        }
        try await container.authManager.login(identifier: "a@b.co", password: "anything")
        #expect(container.authManager.state.user?.name == "Alex Morgan")

        let home = container.makeHomeViewModel()
        await home.load()
        #expect(home.metrics.value?.count == 4)
        #expect(home.activity.value?.first?.id == "act-1001")

        let analytics = container.makeAnalyticsViewModel()
        analytics.range = .week
        await analytics.load()
        #expect(analytics.state.value?.series.first?.points.count == 7)

        let notifications = container.makeNotificationsViewModel()
        await notifications.load()
        #expect(notifications.unreadCount == 2)

        await container.authManager.logout()
        #expect(container.coordinator.route == .login(nil))
    }

    @Test func emptyScenarioProducesEmptyStates() async throws {
        let container = makeContainer(.emptyDashboard)
        await container.authManager.restoreSession()
        try await container.authManager.login(identifier: "a@b.co", password: "pw")
        let home = container.makeHomeViewModel()
        await home.load()
        #expect(home.metrics == .empty)
        #expect(home.activity == .empty)
    }
}
