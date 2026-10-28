import Foundation

struct UserProfile: Equatable, Sendable {
    let id: String
    let name: String
    let email: String?
    let role: String?
    let organization: String?
    let phone: String?
    let memberSince: Date?
    /// Must be a public URL: avatar images are loaded without credentials.
    let avatarURL: URL?
}

protocol ProfileRepository: Sendable {
    func fetchProfile() async throws -> UserProfile
}
