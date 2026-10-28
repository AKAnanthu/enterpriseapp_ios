import Foundation

/// Static configuration for the HTTP layer, derived from `AppConfiguration`.
struct APIConfiguration: Sendable, Equatable {
    var baseURL: URL
    var requestTimeout: TimeInterval
    var defaultHeaders: [String: String]
    var retryPolicy: RetryPolicy

    init(
        baseURL: URL,
        requestTimeout: TimeInterval = 30,
        defaultHeaders: [String: String] = [:],
        retryPolicy: RetryPolicy = .standard
    ) {
        self.baseURL = baseURL
        self.requestTimeout = requestTimeout
        self.defaultHeaders = defaultHeaders
        self.retryPolicy = retryPolicy
    }
}

extension URLSessionConfiguration {
    /// Session configuration for API traffic.
    ///
    /// - `ephemeral`: no persistent URL cache, cookie store or credential store on disk, so
    ///   authenticated responses are never written to the app's caches directory.
    /// - `waitsForConnectivity = false`: fail fast so the UI can show an offline state instead of hanging.
    /// - TLS validation is left to the system defaults (App Transport Security). Never weaken it.
    static func api(timeout: TimeInterval) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        return configuration
    }
}
