import Foundation

/// Process-level switches read once at launch.
///
/// Demo mode and UI-test mode exist only in DEBUG builds. They replace the HTTP transport with
/// `MockBackendTransport` and the keychain with an in-memory store; everything else (request
/// building, decoding, auth, view models) runs exactly as in production.
struct LaunchOptions: Sendable {
    /// The app is hosting the unit-test bundle; skip normal startup.
    var isHostingUnitTests = false
    /// `-demo-mode` or `-ui-testing`.
    var usesDemoBackend = true
    var isUITesting = true
    var mockScenario: String?
    /// `-network-verbose-logging`: logs redacted headers and request bodies (DEBUG only).
    var verboseNetworkLogging = false

    static func current(_ processInfo: ProcessInfo = .processInfo) -> LaunchOptions {
        var options = LaunchOptions()
        options.isHostingUnitTests = processInfo.environment["XCTestConfigurationFilePath"] != nil
        #if DEBUG
        let arguments = processInfo.arguments
        options.isUITesting = arguments.contains("-ui-testing")
        options.usesDemoBackend = options.isUITesting || arguments.contains("-demo-mode")
        options.mockScenario = processInfo.environment["MOCK_SCENARIO"]
        options.verboseNetworkLogging = arguments.contains("-network-verbose-logging")
        #endif
        return options
    }
}
