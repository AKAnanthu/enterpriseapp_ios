import Foundation

/// Validates HTTP status codes and parses retry guidance.
enum ResponseValidator {
    static func validate(_ response: HTTPURLResponse, now: Date) throws(APIError) {
        guard !(200...299).contains(response.statusCode) else { return }
        let retryAfter = retryAfterInterval(response.value(forHTTPHeaderField: "Retry-After"), now: now)
        throw APIError.from(statusCode: response.statusCode, retryAfter: retryAfter)
    }

    /// Parses `Retry-After` as delta-seconds or an HTTP-date (RFC 9110 §10.2.3).
    static func retryAfterInterval(_ value: String?, now: Date) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = TimeInterval(value), seconds >= 0 {
            return seconds
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
