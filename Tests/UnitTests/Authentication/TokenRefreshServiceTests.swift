import Foundation
import Testing
@testable import NativeBusinessApp

@Suite("TokenRefreshService")
struct TokenRefreshServiceTests {
    @Test func returnsStoredTokenWhenNotExpired() async throws {
        let refresher = MockTokenRefresher()
        let service = TokenRefreshService(store: InMemoryTokenStore(tokens: Fixtures.tokens), refresher: refresher)
        #expect(try await service.validAccessToken() == "access-1")
        #expect(refresher.calls.isEmpty)
    }

    @Test func refreshesProactivelyWhenExpiryIsKnown() async throws {
        let now = Fixtures.referenceDate
        let expiring = AuthTokens(accessToken: "access-1", refreshToken: "refresh-1", expiresAt: now.addingTimeInterval(10))
        let refresher = MockTokenRefresher()
        let service = TokenRefreshService(store: InMemoryTokenStore(tokens: expiring), refresher: refresher,
                                          expiryLeeway: 30, now: { now })
        #expect(try await service.validAccessToken() == "access-2")
        #expect(refresher.calls == ["refresh-1"])
    }

    @Test func concurrentRefreshesAreCoalesced() async throws {
        let refresher = MockTokenRefresher(delay: .milliseconds(150))
        let service = TokenRefreshService(store: InMemoryTokenStore(tokens: Fixtures.tokens), refresher: refresher)

        let tokens = try await withThrowingTaskGroup(of: String.self, returning: [String].self) { group in
            for _ in 0..<8 {
                group.addTask { try await service.refreshAccessToken(rejectedToken: "access-1") }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        #expect(tokens == Array(repeating: "access-2", count: 8))
        #expect(refresher.calls.count == 1)
    }

    @Test func staleRejectedTokenReturnsCurrentTokenWithoutRefreshing() async throws {
        let refresher = MockTokenRefresher()
        let service = TokenRefreshService(store: InMemoryTokenStore(tokens: Fixtures.refreshedTokens), refresher: refresher)
        #expect(try await service.refreshAccessToken(rejectedToken: "access-1") == "access-2")
        #expect(refresher.calls.isEmpty)
    }

    @Test(arguments: [APIError.unauthorized, .forbidden, .validationFailed])
    func permanentFailureClearsSession(error: APIError) async throws {
        let store = InMemoryTokenStore(tokens: Fixtures.tokens)
        let service = TokenRefreshService(store: store, refresher: MockTokenRefresher(result: .failure(error)))
        var events = service.events.makeAsyncIterator()

        await #expect(throws: AuthError.sessionExpired) { try await service.refresh() }

        #expect(try store.load() == nil)
        #expect(try await service.currentTokens() == nil)
        #expect(await events.next() == .refreshStarted)
        #expect(await events.next() == .sessionExpired)
    }

    @Test(arguments: [APIError.noConnection, .timeout, .server(statusCode: 503)])
    func transientFailureKeepsSession(error: APIError) async throws {
        let store = InMemoryTokenStore(tokens: Fixtures.tokens)
        let refresher = MockTokenRefresher(result: .failure(error))
        let service = TokenRefreshService(store: store, refresher: refresher)

        await #expect(throws: error) { try await service.refresh() }
        #expect(try store.load() == Fixtures.tokens)

        // A later attempt starts a new refresh rather than reusing the failed one.
        refresher.setResult(.success(Fixtures.refreshedTokens))
        #expect(try await service.refresh() == Fixtures.refreshedTokens)
        #expect(refresher.calls.count == 2)
    }

    @Test func missingRefreshTokenExpiresSession() async {
        let tokens = AuthTokens(accessToken: "access-1", refreshToken: nil, expiresAt: nil)
        let refresher = MockTokenRefresher()
        let service = TokenRefreshService(store: InMemoryTokenStore(tokens: tokens), refresher: refresher)
        await #expect(throws: AuthError.sessionExpired) { try await service.refresh() }
        #expect(refresher.calls.isEmpty)
    }

    @Test func clearingDuringRefreshDiscardsTheResult() async throws {
        let store = InMemoryTokenStore(tokens: Fixtures.tokens)
        let service = TokenRefreshService(store: store, refresher: MockTokenRefresher(delay: .milliseconds(200)))

        let refresh = Task { try await service.refresh() }
        try await Task.sleep(for: .milliseconds(50))
        try await service.clear()

        await #expect(throws: (any Error).self) { try await refresh.value }
        #expect(try store.load() == nil)
        #expect(try await service.currentTokens() == nil)
    }

    @Test func keychainFailureSurfacesAsKeychainError() async {
        let store = InMemoryTokenStore(tokens: Fixtures.tokens)
        store.simulateFailure(.unexpectedStatus(-25_300))
        let service = TokenRefreshService(store: store, refresher: MockTokenRefresher())
        await #expect(throws: KeychainError.unexpectedStatus(-25_300)) { try await service.validAccessToken() }
    }
}
