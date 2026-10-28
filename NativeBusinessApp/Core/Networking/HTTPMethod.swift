import Foundation

/// HTTP methods supported by the API layer.
enum HTTPMethod: String, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"

    /// Idempotent methods (RFC 9110 §9.2.2) may be retried automatically after a transient failure.
    /// POST and PATCH are never retried automatically because the server may already have applied them.
    var isIdempotent: Bool {
        switch self {
        case .get, .put, .delete: true
        case .post, .patch: false
        }
    }
}
