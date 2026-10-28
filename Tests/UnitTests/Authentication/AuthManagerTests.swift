import Foundation
import Testing
@testable import NativeBusinessApp

@MainActor
@Suite("AuthManager state transitions")
struct AuthManagerTests {
    private func makeManager(
        tokens: AuthTokens? = nil,
        repository: MockAuthRepository = MockAuthRepository(),
        refresher: MockTokenRefresher = MockTokenRefresher()
    ) -> (AuthManager, InMemoryTokenStore, TokenRefreshService) {
        let store = InMemoryTokenStore(tokens: tokens)
        let service = TokenRefreshService(store: store, refresher: refresher)
        return (AuthManager(repository: repository, tokenService: service), store, service)
    }

    @Test func startsInitializing() {
        let (manager, _, _) = makeManager()
        #expect(manager.state == .initializing)
    }

    @Test func restoreWithoutTokensIsUnauthenticated() async {
        let repository = MockAuthRepository()
        let (manager, _, _) = makeManager(repository: repository)
        await manager.restoreSession()
        #expect(manager.state == .unauthenticated)
        #expect(repository.state.withLock { $0.currentUserCalls } == 0)
    }

    @Test func restoreValidatesTokensWithServer() async {
        let repository = MockAuthRepository()
        let (manager, _, _) = makeManager(tokens: Fixtures.tokens, repository: repository)
        await manager.restoreSession()
        #expect(manager.state == .authenticated(Fixtures.user))
        #expect(repository.state.withLock { $0.currentUserCalls } == 1)
    }

    @Test func restoreRejectedByServerExpiresSession() async throws {
        let repository = MockAuthRepository()
        repository.update { $0.currentUserResult = .failure(AuthError.sessionExpired) }
        let (manager, store, _) = makeManager(tokens: Fixtures.tokens, repository: repository)
        await manager.restoreSession()
        #expect(manager.state == .sessionExpired)
        #expect(try store.load() == nil)
    }

    @Test func restoreWhileOfflineKeepsTokensAndOffersRetry() async throws {
        let repository = MockAuthRepository()
        repository.update { $0.currentUserResult = .failure(APIError.noConnection) }
        let (manager, store, _) = makeManager(tokens: Fixtures.tokens, repository: repository)

        await manager.restoreSession()
        guard case .restorationFailed(let error) = manager.state else {
            Issue.record("Expected restorationFailed, got \(manager.state)")
            return
        }
        #expect(error.kind == .offline)
        #expect(try store.load() == Fixtures.tokens)

        repository.update { $0.currentUserResult = .success(Fixtures.user) }
        await manager.restoreSession()
        #expect(manager.state == .authenticated(Fixtures.user))
    }

    @Test func unreadableKeychainItemFallsBackToLogin() async {
        let store = InMemoryTokenStore(tokens: Fixtures.tokens)
        store.simulateFailure(.invalidItemData)
        let manager = AuthManager(repository: MockAuthRepository(),
                                  tokenService: TokenRefreshService(store: store, refresher: MockTokenRefresher()))
        await manager.restoreSession()
        #expect(manager.state == .unauthenticated)
    }

    @Test func transientKeychainFailureKeepsTokensAndOffersRetry() async throws {
        let store = InMemoryTokenStore(tokens: Fixtures.tokens)
        store.simulateFailure(.unexpectedStatus(-25_308)) // errSecInteractionNotAllowed
        let manager = AuthManager(repository: MockAuthRepository(),
                                  tokenService: TokenRefreshService(store: store, refresher: MockTokenRefresher()))
        await manager.restoreSession()
        guard case .restorationFailed(let error) = manager.state else {
            Issue.record("Expected restorationFailed, got \(manager.state)")
            return
        }
        #expect(error.kind == .storage)

        store.simulateFailure(nil)
        #expect(try store.load() == Fixtures.tokens)
        await manager.restoreSession()
        #expect(manager.state == .authenticated(Fixtures.user))
    }

    @Test func loginStoresTokensAndAuthenticates() async throws {
        let (manager, store, _) = makeManager()
        await manager.restoreSession()
        try await manager.login(identifier: "user@example.com", password: "pw")
        #expect(manager.state == .authenticated(Fixtures.user))
        #expect(try store.load() == Fixtures.tokens)
    }

    @Test func loginFetchesUserWhenResponseOmitsIt() async throws {
        let repository = MockAuthRepository()
        repository.update { $0.loginResult = .success(AuthSession(tokens: Fixtures.tokens, user: nil)) }
        let (manager, _, _) = makeManager(repository: repository)
        await manager.restoreSession()
        try await manager.login(identifier: "user@example.com", password: "pw")
        #expect(manager.state == .authenticated(Fixtures.user))
        #expect(repository.state.withLock { $0.currentUserCalls } == 1)
    }

    @Test func failedLoginReturnsToUnauthenticated() async throws {
        let repository = MockAuthRepository()
        repository.update { $0.loginResult = .failure(AuthError.invalidCredentials) }
        let (manager, store, _) = makeManager(repository: repository)
        await manager.restoreSession()

        await #expect(throws: AuthError.invalidCredentials) {
            try await manager.login(identifier: "user@example.com", password: "bad")
        }
        #expect(manager.state == .unauthenticated)
        #expect(try store.load() == nil)
    }

    @Test func keychainFailureDuringLoginDoesNotAuthenticate() async {
        let store = InMemoryTokenStore()
        let manager = AuthManager(repository: MockAuthRepository(),
                                  tokenService: TokenRefreshService(store: store, refresher: MockTokenRefresher()))
        await manager.restoreSession()
        store.simulateFailure(.unexpectedStatus(-34_018))
        await #expect(throws: KeychainError.unexpectedStatus(-34_018)) {
            try await manager.login(identifier: "user@example.com", password: "pw")
        }
        #expect(manager.state == .unauthenticated)
    }

    @Test func logoutClearsCredentialsAndRevokesRemotely() async throws {
        let repository = MockAuthRepository()
        let (manager, store, _) = makeManager(tokens: Fixtures.tokens, repository: repository)
        await manager.restoreSession()

        await manager.logout()

        #expect(manager.state == .unauthenticated)
        #expect(try store.load() == nil)
        #expect(repository.state.withLock { $0.logoutCalls } == ["refresh-1"])
    }

    @Test func refreshEventsKeepUserSignedIn() async {
        let (manager, _, _) = makeManager(tokens: Fixtures.tokens)
        await manager.restoreSession()
        manager.handle(.refreshStarted)
        #expect(manager.state == .refreshing(Fixtures.user))
        manager.handle(.refreshSucceeded)
        #expect(manager.state == .authenticated(Fixtures.user))
    }

    @Test func permanentRefreshFailureExpiresActiveSession() async throws {
        let refresher = MockTokenRefresher(result: .failure(APIError.unauthorized))
        let (manager, _, service) = makeManager(tokens: Fixtures.tokens, refresher: refresher)
        await manager.restoreSession()
        #expect(manager.state == .authenticated(Fixtures.user))

        _ = try? await service.refresh()

        await waitUntil { manager.state == .sessionExpired }
        manager.acknowledgeSessionEnded()
        #expect(manager.state == .unauthenticated)
    }

    @Test func sessionExpiryAfterLogoutIsIgnored() async {
        let (manager, _, _) = makeManager(tokens: Fixtures.tokens)
        await manager.restoreSession()
        await manager.logout()
        manager.handle(.sessionExpired)
        #expect(manager.state == .unauthenticated)
    }

    @Test func logoutDuringRestoreWins() async {
        let repository = MockAuthRepository()
        repository.update { $0.currentUserDelay = .milliseconds(200) }
        let (manager, _, _) = makeManager(tokens: Fixtures.tokens, repository: repository)

        let restore = Task { await manager.restoreSession() }
        try? await Task.sleep(for: .milliseconds(50))
        await manager.logout()
        await restore.value

        #expect(manager.state == .unauthenticated)
    }

    @Test func duplicateLoginIsIgnoredWhileAuthenticating() async throws {
        let (manager, _, _) = makeManager()
        await manager.restoreSession()
        try await manager.login(identifier: "user@example.com", password: "pw")
        // Already authenticated: a second login is a no-op.
        try await manager.login(identifier: "other@example.com", password: "pw")
        #expect(manager.state == .authenticated(Fixtures.user))
    }
}
