import Foundation

/// Session-level backend operations. Implemented by `RemoteAuthRepository`.
protocol AuthRepository: Sendable {
    /// Exchanges credentials for tokens. Throws `AuthError.invalidCredentials` on rejection.
    func login(identifier: String, password: String) async throws -> AuthSession
    /// Fetches the current user using the stored session. Used to validate a restored session.
    func currentUser() async throws -> User
    /// Best-effort server-side revocation. Callers ignore failures.
    func logout(refreshToken: String?) async throws
}

/// Exchanges a refresh token for a new token bundle. Implemented by `RemoteTokenRefresher`.
protocol TokenRefreshing: Sendable {
    func refreshTokens(using refreshToken: String) async throws -> AuthTokens
}
