import Foundation

/// Which identifier the backend expects at login. Configured via `LOGIN_IDENTIFIER_KIND`.
enum LoginIdentifierKind: String, Sendable, CaseIterable {
    case email
    case username
}

/// Field-level validation errors for the login form.
enum LoginFieldError: Equatable, Sendable {
    case identifierRequired(LoginIdentifierKind)
    case invalidEmail
    case passwordRequired

    var message: String {
        switch self {
        case .identifierRequired(.email): String(localized: "Enter your email address.")
        case .identifierRequired(.username): String(localized: "Enter your username.")
        case .invalidEmail: String(localized: "Enter a valid email address, like name@example.com.")
        case .passwordRequired: String(localized: "Enter your password.")
        }
    }
}

/// Client-side validation that catches obvious mistakes before a network round trip.
///
/// It deliberately does not enforce password length or complexity: those rules belong to the
/// backend, and duplicating them risks rejecting valid passwords.
struct LoginFormValidator: Sendable {
    let identifierKind: LoginIdentifierKind

    struct Result: Equatable, Sendable {
        /// The identifier with surrounding whitespace removed. The password is never altered.
        let normalizedIdentifier: String
        let identifierError: LoginFieldError?
        let passwordError: LoginFieldError?

        var isValid: Bool { identifierError == nil && passwordError == nil }
    }

    func validate(identifier: String, password: String) -> Result {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let identifierError: LoginFieldError? = if trimmed.isEmpty {
            .identifierRequired(identifierKind)
        } else if identifierKind == .email, !Self.isPlausibleEmail(trimmed) {
            .invalidEmail
        } else {
            nil
        }
        return Result(
            normalizedIdentifier: trimmed,
            identifierError: identifierError,
            passwordError: password.isEmpty ? .passwordRequired : nil
        )
    }

    /// Pragmatic check: one `@`, a non-empty local part, a dotted domain, no whitespace.
    /// The backend remains the authority on whether the address exists.
    static func isPlausibleEmail(_ value: String) -> Bool {
        guard !value.contains(where: \.isWhitespace) else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domainLabels = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domainLabels.count >= 2 && domainLabels.allSatisfy { !$0.isEmpty }
    }
}
