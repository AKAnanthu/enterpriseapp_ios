import Foundation
import Observation

/// Top-level destinations. Derived entirely from `AuthManager.state`, which is the single source
/// of truth, so two simultaneous state changes can never produce conflicting navigation.
enum AppRoute: Equatable {
    case launching
    case login(LoginNotice?)
    case main(User)
    case restorationFailed(UserFacingError)
}

@MainActor
@Observable
final class AppCoordinator {
    let authManager: AuthManager
    @ObservationIgnored private var hasStarted = false

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var route: AppRoute {
        switch authManager.state {
        case .initializing: .launching
        case .unauthenticated, .authenticating: .login(nil)
        case .sessionExpired: .login(.sessionExpired)
        case .authenticated(let user), .refreshing(let user): .main(user)
        case .restorationFailed(let error): .restorationFailed(error)
        }
    }

    /// Restores the stored session once per launch. Runs asynchronously so the first frame
    /// (the launch view) is never blocked by keychain or network work.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await authManager.restoreSession()
    }

    func retryRestoration() async {
        await authManager.restoreSession()
    }

    func abandonRestoration() async {
        await authManager.logout()
    }
}
