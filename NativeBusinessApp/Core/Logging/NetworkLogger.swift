import Foundation
import OSLog

/// Privacy-conscious request logging.
///
/// By default only the method, the URL path (no query string) and the status code are logged.
/// Verbose mode (DEBUG builds only, opt-in via the `-network-verbose-logging` launch argument)
/// adds redacted headers and a redacted request body; response bodies are never logged.
struct NetworkLogger: Sendable {
    private let logger: Logger
    private let isVerbose: Bool

    init(logger: Logger = AppLogger.network, isVerbose: Bool = false) {
        self.logger = logger
        #if DEBUG
        self.isVerbose = isVerbose
        #else
        self.isVerbose = false
        #endif
    }

    func willSend(_ request: URLRequest) {
        if isVerbose {
            logger.debug("→ \(LogRedactor.describe(request, includeBody: true), privacy: .private)")
        } else {
            logger.debug("→ \(request.httpMethod ?? "GET", privacy: .public) \(request.url?.path() ?? "", privacy: .private)")
        }
    }

    func didReceive(_ response: HTTPURLResponse, for request: URLRequest, duration: Duration) {
        let milliseconds = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
        logger.debug(
            "← \(response.statusCode, privacy: .public) \(request.httpMethod ?? "GET", privacy: .public) \(request.url?.path() ?? "", privacy: .private) (\(milliseconds, privacy: .public) ms)"
        )
    }

    func didFail(_ request: URLRequest, error: APIError) {
        logger.error(
            "✕ \(request.httpMethod ?? "GET", privacy: .public) \(request.url?.path() ?? "", privacy: .private): \(String(describing: error), privacy: .public)"
        )
    }

    func willRetry(_ request: URLRequest, attempt: Int, delay: TimeInterval, after error: APIError) {
        logger.notice(
            "↻ retry #\(attempt, privacy: .public) in \(delay, privacy: .public)s for \(request.httpMethod ?? "GET", privacy: .public) \(request.url?.path() ?? "", privacy: .private) after \(String(describing: error), privacy: .public)"
        )
    }

    func decodingFailed(_ typeName: String, error: any Error) {
        // DecodingError descriptions contain coding paths, not payload values.
        logger.error("Decoding \(typeName, privacy: .public) failed: \(String(describing: error), privacy: .private)")
    }
}
