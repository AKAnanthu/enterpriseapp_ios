import Foundation

/// The networking interface used by repositories.
protocol APIClient: Sendable {
    func send<Response>(_ endpoint: APIEndpoint<Response>) async throws -> Response
}

/// Supplies access tokens to `AuthenticatedAPIClient` and coordinates refreshes.
/// Implemented by `TokenRefreshService`.
protocol AccessTokenProvider: Sendable {
    /// Returns a token believed to be valid, refreshing proactively if it is known to be expired.
    func validAccessToken() async throws -> String
    /// Called after the server rejected `rejectedToken` with 401. Implementations must coalesce
    /// concurrent calls into a single refresh.
    func refreshAccessToken(rejectedToken: String) async throws -> String
    /// Called when a freshly refreshed token is still rejected; the session must end.
    func invalidateSession() async
}

/// `APIClient` used by feature repositories.
///
/// For endpoints that require authentication it attaches the bearer token and, on `401`,
/// performs at most one refresh followed by one retry. A second `401` ends the session.
/// Replaying a non-idempotent request here is safe because a `401` means the server rejected
/// the request before processing it.
final class AuthenticatedAPIClient: APIClient {
    private let httpClient: HTTPClient
    private let tokenProvider: any AccessTokenProvider

    init(httpClient: HTTPClient, tokenProvider: any AccessTokenProvider) {
        self.httpClient = httpClient
        self.tokenProvider = tokenProvider
    }

    func send<Response>(_ endpoint: APIEndpoint<Response>) async throws -> Response {
        guard endpoint.requiresAuthentication else {
            return try await httpClient.send(endpoint, accessToken: nil)
        }

        let token = try await tokenProvider.validAccessToken()
        do {
            return try await httpClient.send(endpoint, accessToken: token)
        } catch .unauthorized {
            let refreshedToken = try await tokenProvider.refreshAccessToken(rejectedToken: token)
            do {
                return try await httpClient.send(endpoint, accessToken: refreshedToken)
            } catch .unauthorized {
                await tokenProvider.invalidateSession()
                throw APIError.unauthorized
            }
        }
    }
}
