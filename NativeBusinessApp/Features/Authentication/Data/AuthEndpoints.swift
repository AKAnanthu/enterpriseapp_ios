import Foundation

/// Authentication endpoint definitions.
/// ASSUMPTION: illustrative paths; see Documentation/API_INTEGRATION.md.
enum AuthEndpoints {
    enum Path {
        static let login = "auth/login"
        static let refresh = "auth/refresh"
        static let currentUser = "auth/me"
        static let logout = "auth/logout"
    }

    static func login(_ request: LoginRequestDTO) -> APIEndpoint<LoginResponseDTO> {
        APIEndpoint(path: Path.login, method: .post, body: request, requiresAuthentication: false)
    }

    /// Never authenticated with the access token, so a refresh can never trigger another refresh.
    static func refresh(_ request: RefreshRequestDTO) -> APIEndpoint<TokenResponseDTO> {
        APIEndpoint(path: Path.refresh, method: .post, body: request, requiresAuthentication: false)
    }

    static func currentUser() -> APIEndpoint<UserDTO> {
        APIEndpoint(path: Path.currentUser)
    }

    /// Best-effort revocation with a short timeout so sign-out never feels slow.
    static func logout(_ request: LogoutRequestDTO) -> APIEndpoint<EmptyResponse> {
        APIEndpoint(path: Path.logout, method: .post, body: request, requiresAuthentication: false, timeout: 5)
    }
}
