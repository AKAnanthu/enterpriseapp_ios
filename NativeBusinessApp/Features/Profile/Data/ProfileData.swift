import Foundation

// ASSUMPTION: illustrative contract (Documentation/API_INTEGRATION.md), not a verified backend schema.

/// `GET /profile`
struct ProfileDTO: Decodable, Sendable {
    let id: String
    let name: String
    let email: String?
    let role: String?
    let organization: String?
    let phone: String?
    let memberSince: Date?
    let avatarURL: String?
}

enum ProfileEndpoints {
    enum Path {
        static let profile = "profile"
    }

    static func profile() -> APIEndpoint<ProfileDTO> {
        APIEndpoint(path: Path.profile)
    }
}

enum ProfileMapper {
    static func profile(from dto: ProfileDTO) -> UserProfile {
        UserProfile(
            id: dto.id,
            name: dto.name,
            email: dto.email,
            role: dto.role,
            organization: dto.organization,
            phone: dto.phone,
            memberSince: dto.memberSince,
            // Only HTTPS avatars are loaded.
            avatarURL: dto.avatarURL.flatMap(URL.init(string:)).flatMap { $0.scheme?.lowercased() == "https" ? $0 : nil }
        )
    }
}

struct RemoteProfileRepository: ProfileRepository {
    let apiClient: any APIClient

    func fetchProfile() async throws -> UserProfile {
        ProfileMapper.profile(from: try await apiClient.send(ProfileEndpoints.profile()))
    }
}
