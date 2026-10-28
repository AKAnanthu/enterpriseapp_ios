import Foundation

// ASSUMPTION: These DTOs model the *illustrative* contract in Documentation/API_INTEGRATION.md.
// They have not been verified against a real backend. Adjust field names here (and only here)
// when the real contract is known; the domain and UI layers will not need to change.

/// `POST /auth/login` request. Encodes `email` or `username` depending on configuration.
struct LoginRequestDTO: Encodable, Sendable {
    let identifierKind: LoginIdentifierKind
    let identifier: String
    let password: String

    private enum CodingKeys: String, CodingKey {
        case email, username, password
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch identifierKind {
        case .email: try container.encode(identifier, forKey: .email)
        case .username: try container.encode(identifier, forKey: .username)
        }
        try container.encode(password, forKey: .password)
    }
}

/// Token payload returned by login and refresh.
struct TokenResponseDTO: Decodable, Sendable {
    let accessToken: String?
    let refreshToken: String?
    /// Seconds until the access token expires.
    let expiresIn: Double?
    let tokenType: String?
}

/// `POST /auth/login` response: tokens plus an optional embedded user.
struct LoginResponseDTO: Decodable, Sendable {
    let tokens: TokenResponseDTO
    let user: UserDTO?

    private enum CodingKeys: String, CodingKey {
        case user
    }

    init(from decoder: any Decoder) throws {
        tokens = try TokenResponseDTO(from: decoder)
        user = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(UserDTO.self, forKey: .user)
    }
}

struct UserDTO: Decodable, Sendable {
    let id: String
    let name: String?
    let email: String?
}

/// `POST /auth/refresh` request.
struct RefreshRequestDTO: Encodable, Sendable {
    let refreshToken: String
}

/// `POST /auth/logout` request.
struct LogoutRequestDTO: Encodable, Sendable {
    let refreshToken: String?
}
