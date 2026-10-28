import Foundation

/// Every failure produced by the networking layer is mapped to one of these cases.
///
/// Associated values never contain response bodies, tokens or other sensitive data.
enum APIError: Error, Equatable, Sendable {
    case invalidConfiguration(String)
    case invalidURL
    case invalidRequest
    case noConnection
    case cannotReachServer
    case timeout
    case cancelled
    case unauthorized
    case forbidden
    case notFound
    case validationFailed
    case rateLimited(retryAfter: TimeInterval?)
    case server(statusCode: Int)
    case unexpectedStatus(Int)
    case invalidResponse
    case emptyResponse
    /// The payload did not match the expected type. The associated value names the type only.
    case decodingFailed(String)
    case keychain(KeychainError)
    case transport(code: Int)

    init(urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff, .callIsActive:
            self = .noConnection
        case .timedOut:
            self = .timeout
        case .cancelled:
            self = .cancelled
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            self = .cannotReachServer
        case .badURL, .unsupportedURL:
            self = .invalidURL
        default:
            self = .transport(code: urlError.code.rawValue)
        }
    }

    /// Normalises any error thrown while performing a request.
    init(_ error: any Error) {
        switch error {
        case let apiError as APIError: self = apiError
        case let urlError as URLError: self.init(urlError: urlError)
        case is CancellationError: self = .cancelled
        case let keychainError as KeychainError: self = .keychain(keychainError)
        default: self = .transport(code: (error as NSError).code)
        }
    }

    /// Maps a non-2xx HTTP status code.
    static func from(statusCode: Int, retryAfter: TimeInterval? = nil) -> APIError {
        switch statusCode {
        case 400, 422: .validationFailed
        case 401: .unauthorized
        case 403: .forbidden
        case 404: .notFound
        case 408: .timeout
        case 429: .rateLimited(retryAfter: retryAfter)
        case 500...599: .server(statusCode: statusCode)
        default: .unexpectedStatus(statusCode)
        }
    }
}
