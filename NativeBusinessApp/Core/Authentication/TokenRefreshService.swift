import Foundation

/// Owns the token bundle in memory and in the `TokenStore`, and serialises refreshes.
///
/// Guarantees:
/// - At most one refresh request is in flight; concurrent callers await the same task.
/// - A caller whose rejected token has already been replaced receives the new token without
///   triggering another refresh.
/// - The refresh call goes through `HTTPClient` without authentication, so it can never recurse.
/// - A permanent refresh failure (`401`/`403`/`400`/`422`, or no refresh token) clears the
///   session and emits `.sessionExpired`. Transient failures keep the tokens and are rethrown.
/// - Clearing the session while a refresh is in flight discards that refresh's result.
actor TokenRefreshService: AccessTokenProvider {
    private let tokenStore: any TokenStore
    private let refresher: any TokenRefreshing
    private let now: @Sendable () -> Date
    private let expiryLeeway: TimeInterval

    private var tokens: AuthTokens?
    private var hasLoadedFromStore = false
    private var refreshTask: Task<AuthTokens, any Error>?
    /// Incremented whenever the session is replaced or cleared, so stale refresh results are dropped.
    private var generation = 0

    nonisolated let events: AsyncStream<SessionEvent>
    private let eventContinuation: AsyncStream<SessionEvent>.Continuation

    init(
        store: any TokenStore,
        refresher: any TokenRefreshing,
        expiryLeeway: TimeInterval = 30,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.tokenStore = store
        self.refresher = refresher
        self.expiryLeeway = expiryLeeway
        self.now = now
        (events, eventContinuation) = AsyncStream.makeStream(of: SessionEvent.self, bufferingPolicy: .bufferingNewest(8))
    }

    deinit {
        eventContinuation.finish()
    }

    // MARK: Session storage

    /// Returns the stored tokens, reading the keychain once per process.
    func currentTokens() throws(KeychainError) -> AuthTokens? {
        if !hasLoadedFromStore {
            tokens = try tokenStore.load()
            hasLoadedFromStore = true
        }
        return tokens
    }

    func save(_ newTokens: AuthTokens) throws(KeychainError) {
        try tokenStore.save(newTokens)
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        tokens = newTokens
        hasLoadedFromStore = true
    }

    /// Removes tokens from memory and the keychain. Memory is cleared even if the keychain fails.
    func clear() throws(KeychainError) {
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        tokens = nil
        hasLoadedFromStore = true
        try tokenStore.clear()
    }

    // MARK: AccessTokenProvider

    func validAccessToken() async throws -> String {
        guard let current = try currentTokens() else { throw AuthError.notAuthenticated }
        if current.isAccessTokenExpired(at: now(), leeway: expiryLeeway) {
            return try await refresh().accessToken
        }
        return current.accessToken
    }

    func refreshAccessToken(rejectedToken: String) async throws -> String {
        if let current = try currentTokens(), current.accessToken != rejectedToken {
            return current.accessToken
        }
        return try await refresh().accessToken
    }

    func invalidateSession() async {
        await expireSession()
    }

    // MARK: Refresh

    /// Refreshes tokens, joining an in-flight refresh if there is one.
    @discardableResult
    func refresh() async throws -> AuthTokens {
        if let refreshTask {
            do {
                return try await refreshTask.value
            } catch {
                throw Self.isPermanentRefreshFailure(error) ? AuthError.sessionExpired : error
            }
        }
        guard let refreshToken = try currentTokens()?.refreshToken else {
            await expireSession()
            throw AuthError.sessionExpired
        }

        let startedGeneration = generation
        let refresher = self.refresher
        let task = Task { try await refresher.refreshTokens(using: refreshToken) }
        refreshTask = task
        eventContinuation.yield(.refreshStarted)

        do {
            let newTokens = try await task.value
            guard generation == startedGeneration else { throw AuthError.sessionExpired }
            refreshTask = nil
            try save(newTokens)
            eventContinuation.yield(.refreshSucceeded)
            return newTokens
        } catch {
            if generation == startedGeneration {
                refreshTask = nil
            }
            if Self.isPermanentRefreshFailure(error) {
                if generation == startedGeneration {
                    await expireSession()
                }
                throw AuthError.sessionExpired
            }
            throw error
        }
    }

    private func expireSession() async {
        do {
            try clear()
        } catch {
            AppLogger.auth.error("Clearing tokens after session expiry failed: \(error.debugDescription, privacy: .public)")
        }
        eventContinuation.yield(.sessionExpired)
    }

    static func isPermanentRefreshFailure(_ error: any Error) -> Bool {
        switch error {
        case APIError.unauthorized, APIError.forbidden, APIError.validationFailed,
             AuthError.invalidTokenResponse, AuthError.sessionExpired, AuthError.notAuthenticated:
            true
        default:
            false
        }
    }
}
