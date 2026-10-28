import Foundation
import OSLog

/// Unified logging categories. Dynamic values default to `.private` in `os.Logger`, so they are
/// redacted in logs captured from release devices unless explicitly marked `.public`.
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "NativeBusinessApp"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
}
