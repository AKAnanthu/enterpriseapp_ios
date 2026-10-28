import Foundation

/// Persistent storage for the session's token bundle.
///
/// Access and refresh tokens are stored together as one item, so an update replaces both in a
/// single keychain operation and the store can never hold a new access token with a stale
/// refresh token (or vice versa).
protocol TokenStore: Sendable {
    func load() throws(KeychainError) -> AuthTokens?
    func save(_ tokens: AuthTokens) throws(KeychainError)
    func clear() throws(KeychainError)
}
