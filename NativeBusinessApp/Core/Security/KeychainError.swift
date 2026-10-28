import Foundation
import Security

/// Keychain failures. Never carries secret material.
enum KeychainError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case invalidItemData
    case encodingFailed

    var debugDescription: String {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            return "Keychain status \(status): \(message)"
        case .invalidItemData:
            return "Stored keychain item could not be decoded."
        case .encodingFailed:
            return "Keychain item could not be encoded."
        }
    }
}
