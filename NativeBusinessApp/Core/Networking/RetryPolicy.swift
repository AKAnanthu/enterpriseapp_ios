import Foundation

/// Bounded retry rules for transient failures.
///
/// Only requests whose endpoint allows automatic retry (idempotent by default) are retried, and only for
/// timeouts, `502/503/504`, and `429` responses whose `Retry-After` is within `maxDelay`.
/// Authentication failures are never retried here; see `AuthenticatedAPIClient` for the single
/// refresh-and-retry path.
struct RetryPolicy: Sendable, Equatable {
    var maxRetries: Int
    var baseDelay: TimeInterval
    var maxDelay: TimeInterval

    static let standard = RetryPolicy(maxRetries: 2, baseDelay: 0.5, maxDelay: 8)
    static let disabled = RetryPolicy(maxRetries: 0, baseDelay: 0, maxDelay: 0)

    /// Returns how long to wait before the next attempt, or `nil` when the failure must be surfaced.
    /// - Parameter attempt: zero-based number of retries already performed.
    func delay(after error: APIError, attempt: Int, isRetryEligible: Bool) -> TimeInterval? {
        guard isRetryEligible, attempt < maxRetries else { return nil }
        let backoff = min(maxDelay, baseDelay * pow(2, Double(attempt)))
        switch error {
        case .timeout:
            return backoff
        case .server(let statusCode) where [502, 503, 504].contains(statusCode):
            return backoff
        case .rateLimited(let retryAfter):
            let delay = retryAfter ?? backoff
            return delay <= maxDelay ? delay : nil
        default:
            return nil
        }
    }
}
