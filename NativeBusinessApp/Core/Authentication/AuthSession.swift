import Foundation

/// The result of a successful credential exchange.
struct AuthSession: Equatable, Sendable {
    let tokens: AuthTokens
    /// Present when the login response embeds the user; otherwise fetched separately.
    let user: User?
}

/// The single source of truth for the app's authentication lifecycle.
enum AuthState: Equatable, Sendable {
    /// Restoring a stored session at launch.
    case initializing
    case unauthenticated
    /// A login request is in flight.
    case authenticating
    case authenticated(User)
    /// Signed in while a token refresh is in progress. The UI stays in the authenticated shell.
    case refreshing(User)
    /// A stored or active session was rejected by the server or could not be refreshed.
    case sessionExpired
    /// Tokens exist but could not be validated because of a transient error (for example offline).
    case restorationFailed(UserFacingError)

    var user: User? {
        switch self {
        case .authenticated(let user), .refreshing(let user): user
        default: nil
        }
    }
}

/// Lifecycle notifications emitted by `TokenRefreshService`.
enum SessionEvent: Equatable, Sendable {
    case refreshStarted
    case refreshSucceeded
    case sessionExpired
}
