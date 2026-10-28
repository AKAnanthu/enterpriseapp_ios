import Foundation

/// The credentials issued by the backend. Tokens are treated as opaque strings: the app never
/// decodes or trusts JWT claims; the backend alone decides whether a token is valid.
///
/// `description` is redacted so tokens cannot leak through string interpolation or logging.
struct AuthTokens: Codable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    var accessToken: String
    /// Optional because the backend contract is unknown; without one the session simply ends when
    /// the access token expires.
    var refreshToken: String?
    /// Derived from the response's `expiresIn` at receipt time, not from the token itself.
    var expiresAt: Date?
    var tokenType: String

    init(accessToken: String, refreshToken: String?, expiresAt: Date?, tokenType: String = "Bearer") {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }

    /// `true` when the access token is known to expire within `leeway` seconds of `date`.
    /// Unknown expiry is treated as "not expired": the server's 401 is the source of truth.
    func isAccessTokenExpired(at date: Date, leeway: TimeInterval) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(date) <= leeway
    }

    var description: String {
        "AuthTokens(accessToken: \(LogRedactor.placeholder), refreshToken: \(refreshToken == nil ? "nil" : LogRedactor.placeholder), expiresAt: \(expiresAt.map(String.init(describing:)) ?? "nil"))"
    }

    var debugDescription: String { description }
}
