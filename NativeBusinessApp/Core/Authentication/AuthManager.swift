import Foundation
import Observation

/// Abstraction used by the login screen, so it can be tested without the full session stack.
@MainActor
protocol LoginAuthenticating: AnyObject {
    func login(identifier: String, password: String) async throws
}

/// Abstraction used by screens that can end the session.
@MainActor
protocol SessionTerminating: AnyObject {
    func logout() async
}

/// Owns the observable authentication state. All transitions happen on the main actor, so the
/// root view always sees a consistent state and navigation cannot race.
///
/// Every transition that replaces the session increments `generation`; results of async work
/// started under an older generation (for example a slow restore finishing after logout) are dropped.
@MainActor
@Observable
final class AuthManager: LoginAuthenticating, SessionTerminating {
    private(set) var state: AuthState = .initializing

    @ObservationIgnored private let repository: any AuthRepository
    @ObservationIgnored private let tokenService: TokenRefreshService
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var eventsTask: Task<Void, Never>?

    init(repository: any AuthRepository, tokenService: TokenRefreshService) {
        self.repository = repository
        self.tokenService = tokenService
        observeSessionEvents()
    }

    // MARK: Launch

    /// Restores a stored session. Token presence alone is not trusted: the session is accepted only
    /// after the backend returns the current user (refreshing first if the token is known to be expired).
    func restoreSession() async {
        guard state == .initializing || isRestorationFailure else { return }
        state = .initializing
        let startedGeneration = generation

        let hasTokens: Bool
        do {
            hasTokens = try await tokenService.currentTokens() != nil
        } catch .invalidItemData {
            // The stored item is unreadable and can never become valid again: discard it.
            AppLogger.auth.error("Stored session is corrupt; clearing it.")
            try? await tokenService.clear()
            transition(to: .unauthenticated, ifGeneration: startedGeneration)
            return
        } catch {
            // Possibly transient (e.g. errSecInteractionNotAllowed while the device is locked).
            // Keep the item and let the user retry instead of silently signing them out.
            AppLogger.auth.error("Reading stored session failed: \(error.debugDescription, privacy: .public)")
            transition(to: .restorationFailed(UserFacingError(error)), ifGeneration: startedGeneration)
            return
        }
        guard hasTokens else {
            transition(to: .unauthenticated, ifGeneration: startedGeneration)
            return
        }

        do {
            let user = try await repository.currentUser()
            transition(to: .authenticated(user), ifGeneration: startedGeneration)
        } catch {
            guard generation == startedGeneration else { return }
            if Self.isSessionRejection(error) {
                try? await tokenService.clear()
                transition(to: .sessionExpired, ifGeneration: startedGeneration)
            } else {
                transition(to: .restorationFailed(UserFacingError(error)), ifGeneration: startedGeneration)
            }
        }
    }

    // MARK: Login

    func login(identifier: String, password: String) async throws {
        guard state.user == nil, state != .authenticating else { return }
        generation += 1
        let startedGeneration = generation
        let previousState = state
        state = .authenticating

        do {
            let session = try await repository.login(identifier: identifier, password: password)
            try await tokenService.save(session.tokens)
            let user: User
            if let embeddedUser = session.user {
                user = embeddedUser
            } else {
                user = try await repository.currentUser()
            }
            guard generation == startedGeneration else { return }
            state = .authenticated(user)
            AppLogger.auth.info("Signed in")
        } catch {
            if generation == startedGeneration {
                try? await tokenService.clear()
                state = previousState == .sessionExpired ? .sessionExpired : .unauthenticated
            }
            throw error
        }
    }

    // MARK: Logout

    /// Clears local credentials first (so the UI returns to login immediately), then asks the
    /// backend to revoke the refresh token on a best-effort basis.
    func logout() async {
        generation += 1
        let refreshToken = try? await tokenService.currentTokens()?.refreshToken
        do {
            try await tokenService.clear()
        } catch {
            AppLogger.auth.error("Clearing keychain on logout failed: \(error.debugDescription, privacy: .public)")
        }
        state = .unauthenticated
        AppLogger.auth.info("Signed out")

        do {
            try await repository.logout(refreshToken: refreshToken)
        } catch {
            AppLogger.auth.notice("Remote logout failed or unsupported; local session already cleared.")
        }
    }

    /// Leaves the expired/failed state for the login screen without a message.
    func acknowledgeSessionEnded() {
        if state == .sessionExpired || isRestorationFailure {
            generation += 1
            state = .unauthenticated
        }
    }

    // MARK: Session events

    private func observeSessionEvents() {
        let events = tokenService.events
        eventsTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    func handle(_ event: SessionEvent) {
        switch (event, state) {
        case (.refreshStarted, .authenticated(let user)):
            state = .refreshing(user)
        case (.refreshSucceeded, .refreshing(let user)):
            state = .authenticated(user)
        case (.sessionExpired, .authenticated), (.sessionExpired, .refreshing):
            generation += 1
            state = .sessionExpired
            AppLogger.auth.notice("Session expired")
        default:
            break // Events that don't apply to the current state (e.g. after logout) are ignored.
        }
    }

    // MARK: Helpers

    private var isRestorationFailure: Bool {
        if case .restorationFailed = state { return true }
        return false
    }

    private func transition(to newState: AuthState, ifGeneration expected: Int) {
        guard generation == expected else { return }
        state = newState
    }

    private static func isSessionRejection(_ error: any Error) -> Bool {
        switch error {
        case AuthError.sessionExpired, AuthError.notAuthenticated, APIError.unauthorized, APIError.forbidden:
            true
        default:
            false
        }
    }
}
