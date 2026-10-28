import Foundation

/// Authentication-specific failures surfaced to the presentation layer.
enum AuthError: Error, Equatable, Sendable {
    /// The backend rejected the submitted credentials.
    case invalidCredentials
    /// The backend refused access for an authenticated identity (for example a disabled account).
    case accessDenied
    /// The login or refresh response was missing required token fields.
    case invalidTokenResponse
    /// No stored session exists.
    case notAuthenticated
    /// The session can no longer be refreshed; the user must sign in again.
    case sessionExpired
}
