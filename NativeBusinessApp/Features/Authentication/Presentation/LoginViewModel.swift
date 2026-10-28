import Foundation
import Observation

/// Presentation state and logic for the login form.
@MainActor
@Observable
final class LoginViewModel {
    enum Field: Hashable {
        case identifier
        case password
    }

    var identifier = "" {
        didSet { if identifier != oldValue { identifierError = nil } }
    }
    /// Bound directly to the secure field. Never trimmed, transformed, logged or persisted.
    var password = "" {
        didSet { if password != oldValue { passwordError = nil } }
    }
    var isPasswordRevealed = false

    private(set) var identifierError: LoginFieldError?
    private(set) var passwordError: LoginFieldError?
    private(set) var submissionError: UserFacingError?
    private(set) var isSubmitting = false

    let identifierKind: LoginIdentifierKind
    let passwordResetURL: URL?
    /// Non-blocking environment notice, e.g. a placeholder backend in development builds.
    let environmentNotice: String?

    @ObservationIgnored private let authenticator: any LoginAuthenticating
    @ObservationIgnored private let validator: LoginFormValidator

    init(
        authenticator: any LoginAuthenticating,
        identifierKind: LoginIdentifierKind,
        passwordResetURL: URL? = nil,
        environmentNotice: String? = nil
    ) {
        self.authenticator = authenticator
        self.identifierKind = identifierKind
        self.passwordResetURL = passwordResetURL
        self.environmentNotice = environmentNotice
        self.validator = LoginFormValidator(identifierKind: identifierKind)
    }

    var canSubmit: Bool { !isSubmitting }

    /// Validates locally, then signs in. Navigation happens only when `AuthManager` reports
    /// `.authenticated`; this method never navigates by itself.
    /// - Returns: the field that should receive focus after a validation failure.
    @discardableResult
    func submit() async -> Field? {
        guard !isSubmitting else { return nil }
        submissionError = nil

        let result = validator.validate(identifier: identifier, password: password)
        identifierError = result.identifierError
        passwordError = result.passwordError
        guard result.isValid else {
            return result.identifierError != nil ? .identifier : .password
        }

        identifier = result.normalizedIdentifier
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await authenticator.login(identifier: result.normalizedIdentifier, password: password)
            password = ""
        } catch where error.isCancellation {
            // The screen went away; nothing to present.
        } catch {
            submissionError = presentableError(for: error)
        }
        return nil
    }

    func dismissSubmissionError() {
        submissionError = nil
    }

    private func presentableError(for error: any Error) -> UserFacingError {
        let base = UserFacingError(error)
        guard base.kind == .invalidCredentials else { return base }
        let message = switch identifierKind {
        case .email: String(localized: "The email or password is incorrect.")
        case .username: String(localized: "The username or password is incorrect.")
        }
        return UserFacingError(kind: .invalidCredentials, title: base.title, message: message, isRetryable: false)
    }
}
