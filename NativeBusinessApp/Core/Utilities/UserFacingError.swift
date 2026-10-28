import Foundation

/// A presentable error. Messages are written for users and never include backend details,
/// status codes, payloads or token information.
struct UserFacingError: Error, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case offline
        case serverUnreachable
        case timeout
        case sessionExpired
        case invalidCredentials
        case accessDenied
        case rateLimited
        case notFound
        case validation
        case configuration
        case storage
        case server
        case unknown
    }

    let kind: Kind
    let title: String
    let message: String
    let isRetryable: Bool

    var systemImage: String {
        switch kind {
        case .offline: "wifi.slash"
        case .serverUnreachable: "icloud.slash"
        case .timeout: "clock.badge.exclamationmark"
        case .sessionExpired: "lock"
        case .invalidCredentials, .accessDenied: "person.crop.circle.badge.exclamationmark"
        case .rateLimited: "hourglass"
        case .notFound: "questionmark.folder"
        case .validation: "exclamationmark.circle"
        case .configuration: "gearshape.2"
        case .storage: "lock.trianglebadge.exclamationmark"
        case .server, .unknown: "exclamationmark.triangle"
        }
    }

    init(kind: Kind, title: String, message: String, isRetryable: Bool) {
        self.kind = kind
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
    }

    init(_ error: any Error) {
        if let error = error as? UserFacingError {
            self = error
        } else if let error = error as? AuthError {
            self = Self.map(error)
        } else {
            self = Self.map(APIError(error))
        }
    }

    // MARK: Mapping

    private static func map(_ error: AuthError) -> UserFacingError {
        switch error {
        case .invalidCredentials:
            UserFacingError(kind: .invalidCredentials, title: String(localized: "Sign-in failed"),
                            message: String(localized: "The details you entered are incorrect. Check them and try again."),
                            isRetryable: false)
        case .accessDenied:
            map(APIError.forbidden)
        case .invalidTokenResponse:
            map(APIError.invalidResponse)
        case .notAuthenticated, .sessionExpired:
            map(APIError.unauthorized)
        }
    }

    private static func map(_ error: APIError) -> UserFacingError {
        switch error {
        case .noConnection:
            UserFacingError(kind: .offline, title: String(localized: "You're offline"),
                            message: String(localized: "Check your internet connection and try again."), isRetryable: true)
        case .cannotReachServer:
            UserFacingError(kind: .serverUnreachable, title: String(localized: "Can't reach the server"),
                            message: String(localized: "The service is unavailable right now. Please try again later."), isRetryable: true)
        case .timeout:
            UserFacingError(kind: .timeout, title: String(localized: "Request timed out"),
                            message: String(localized: "The server took too long to respond. Please try again."), isRetryable: true)
        case .unauthorized:
            UserFacingError(kind: .sessionExpired, title: String(localized: "Session expired"),
                            message: String(localized: "Please sign in again to continue."), isRetryable: false)
        case .forbidden:
            UserFacingError(kind: .accessDenied, title: String(localized: "Access denied"),
                            message: String(localized: "Your account doesn't have permission to do this."), isRetryable: false)
        case .rateLimited:
            UserFacingError(kind: .rateLimited, title: String(localized: "Too many requests"),
                            message: String(localized: "Please wait a moment and try again."), isRetryable: true)
        case .notFound:
            UserFacingError(kind: .notFound, title: String(localized: "Not found"),
                            message: String(localized: "The requested information is no longer available."), isRetryable: false)
        case .validationFailed:
            UserFacingError(kind: .validation, title: String(localized: "Check your details"),
                            message: String(localized: "Some of the information couldn't be accepted."), isRetryable: false)
        case .invalidConfiguration, .invalidURL, .invalidRequest:
            UserFacingError(kind: .configuration, title: String(localized: "Configuration problem"),
                            message: String(localized: "The app isn't configured correctly. Please contact support."), isRetryable: false)
        case .keychain:
            UserFacingError(kind: .storage, title: String(localized: "Secure storage unavailable"),
                            message: String(localized: "Your session couldn't be stored securely. Please try again."), isRetryable: true)
        case .server, .unexpectedStatus, .invalidResponse, .emptyResponse, .decodingFailed, .transport:
            UserFacingError(kind: .server, title: String(localized: "Something went wrong"),
                            message: String(localized: "We couldn't complete your request. Please try again."), isRetryable: true)
        case .cancelled:
            UserFacingError(kind: .unknown, title: String(localized: "Request cancelled"),
                            message: String(localized: "The request was cancelled."), isRetryable: true)
        }
    }
}

extension Error {
    /// `true` for task / request cancellation, which screens should not present as a failure.
    var isCancellation: Bool {
        switch self {
        case is CancellationError: true
        case let error as APIError: error == .cancelled
        case let error as URLError: error.code == .cancelled
        default: false
        }
    }
}
