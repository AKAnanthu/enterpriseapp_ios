import Foundation
import Observation

/// Read-only app details shown in the profile's "About" section.
struct AppInfo: Equatable, Sendable {
    let version: String
    let environmentName: String
    let apiHost: String?
}

@MainActor
@Observable
final class ProfileViewModel {
    private(set) var state: LoadState<UserProfile> = .idle
    private(set) var isSigningOut = false
    var isConfirmingSignOut = false

    let sessionUser: User
    let appInfo: AppInfo

    @ObservationIgnored private let repository: any ProfileRepository
    @ObservationIgnored private weak var session: (any SessionTerminating)?

    init(sessionUser: User, appInfo: AppInfo, repository: any ProfileRepository, session: any SessionTerminating) {
        self.sessionUser = sessionUser
        self.appInfo = appInfo
        self.repository = repository
        self.session = session
    }

    /// Name shown in the header: the full profile when loaded, otherwise the session's user.
    var displayName: String { state.value?.name ?? sessionUser.name }
    var displayEmail: String? { state.value?.email ?? sessionUser.email }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await repository.fetchProfile())
        } catch where error.isCancellation {
            if state.isLoading { state = .idle }
        } catch {
            state = .failed(UserFacingError(error))
        }
    }

    func requestSignOut() {
        isConfirmingSignOut = true
    }

    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        await session?.logout()
    }
}
