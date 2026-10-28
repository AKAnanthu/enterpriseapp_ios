import Foundation

/// A typed description of a single REST call. Endpoints are plain values; they never perform I/O.
///
/// `path` is relative to `APIConfiguration.baseURL` and must already be percent-encoded.
/// Build paths that contain dynamic identifiers with ``APIPath/make(_:)`` so identifiers
/// cannot inject extra path segments.
struct APIEndpoint<Response: Decodable & Sendable>: Sendable {
    var path: String
    var method: HTTPMethod
    var queryItems: [URLQueryItem]
    var headers: [String: String]
    var body: (any Encodable & Sendable)?
    /// When `true`, the API client attaches a bearer token and handles a single refresh-and-retry on 401.
    var requiresAuthentication: Bool
    /// Overrides `APIConfiguration.requestTimeout` for this call.
    var timeout: TimeInterval?
    /// Whether transient failures may be retried automatically. Defaults to the method's idempotency.
    var allowsAutomaticRetry: Bool

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: (any Encodable & Sendable)? = nil,
        requiresAuthentication: Bool = true,
        timeout: TimeInterval? = nil,
        allowsAutomaticRetry: Bool? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.requiresAuthentication = requiresAuthentication
        self.timeout = timeout
        self.allowsAutomaticRetry = allowsAutomaticRetry ?? method.isIdempotent
    }
}

/// Response type for endpoints that return no meaningful body (for example `204 No Content`).
struct EmptyResponse: Decodable, Sendable, Equatable {
    init() {}
}

/// Builds percent-encoded relative paths from segments.
enum APIPath {
    private static let segmentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/;")
        return set
    }()

    /// Joins segments with `/`, percent-encoding each one. A segment such as `"a/b"` becomes `"a%2Fb"`.
    static func make(_ segments: String...) -> String {
        segments
            .map { $0.addingPercentEncoding(withAllowedCharacters: segmentAllowed) ?? "" }
            .joined(separator: "/")
    }
}
