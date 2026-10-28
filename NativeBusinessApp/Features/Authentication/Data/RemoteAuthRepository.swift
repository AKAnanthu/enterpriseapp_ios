import Foundation

/// `AuthRepository` backed by the REST API.
struct RemoteAuthRepository: AuthRepository {
    let apiClient: any APIClient
    let identifierKind: LoginIdentifierKind
    /// Whether the backend exposes a logout/revocation endpoint. ASSUMPTION: configurable until known.
    var supportsRemoteLogout = true
    var now: @Sendable () -> Date = { Date() }

    func login(identifier: String, password: String) async throws -> AuthSession {
        let request = LoginRequestDTO(identifierKind: identifierKind, identifier: identifier, password: password)
        let response: LoginResponseDTO
        do {
            response = try await apiClient.send(AuthEndpoints.login(request))
        } catch APIError.unauthorized, APIError.validationFailed {
            // Many backends answer bad credentials with 400/422 instead of 401.
            throw AuthError.invalidCredentials
        } catch APIError.forbidden {
            throw AuthError.accessDenied
        }
        let tokens = try AuthMapper.tokens(from: response.tokens, receivedAt: now())
        return AuthSession(tokens: tokens, user: response.user.map(AuthMapper.user(from:)))
    }

    func currentUser() async throws -> User {
        AuthMapper.user(from: try await apiClient.send(AuthEndpoints.currentUser()))
    }

    func logout(refreshToken: String?) async throws {
        guard supportsRemoteLogout else { return }
        _ = try await apiClient.send(AuthEndpoints.logout(LogoutRequestDTO(refreshToken: refreshToken)))
    }
}

/// Exchanges a refresh token through the unauthenticated `HTTPClient`.
struct RemoteTokenRefresher: TokenRefreshing {
    let httpClient: HTTPClient
    var now: @Sendable () -> Date = { Date() }

    func refreshTokens(using refreshToken: String) async throws -> AuthTokens {
        let response = try await httpClient.send(AuthEndpoints.refresh(RefreshRequestDTO(refreshToken: refreshToken)), accessToken: nil)
        var tokens = try AuthMapper.tokens(from: response, receivedAt: now())
        // ASSUMPTION: if the server does not rotate refresh tokens, keep using the current one.
        if tokens.refreshToken == nil {
            tokens.refreshToken = refreshToken
        }
        return tokens
    }
}
