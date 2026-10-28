import Foundation

enum AuthMapper {
    /// Validates and converts a token payload. Required: a non-empty access token. If a token type
    /// is present it must be `Bearer`, because that is the only scheme the client sends.
    static func tokens(from dto: TokenResponseDTO, receivedAt now: Date) throws(AuthError) -> AuthTokens {
        guard let accessToken = dto.accessToken, !accessToken.isEmpty else {
            throw .invalidTokenResponse
        }
        if let tokenType = dto.tokenType, tokenType.caseInsensitiveCompare("Bearer") != .orderedSame {
            throw .invalidTokenResponse
        }
        let refreshToken = dto.refreshToken.flatMap { $0.isEmpty ? nil : $0 }
        let expiresAt = dto.expiresIn.flatMap { $0 > 0 ? now.addingTimeInterval($0) : nil }
        return AuthTokens(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt, tokenType: "Bearer")
    }

    static func user(from dto: UserDTO) -> User {
        let trimmedName = dto.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.flatMap { $0.isEmpty ? nil : $0 } ?? dto.email ?? String(localized: "Account")
        return User(id: dto.id, name: displayName, email: dto.email)
    }
}
