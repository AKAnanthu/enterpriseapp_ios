#if DEBUG
import Foundation
import Synchronization

/// Non-persistent token store used by unit tests and the DEBUG-only demo / UI-test mode,
/// so automated runs never touch the real keychain item.
final class InMemoryTokenStore: TokenStore {
    private let state: Mutex<State>

    private struct State {
        var tokens: AuthTokens?
        var failure: KeychainError?
        var saveCount = 0
    }

    init(tokens: AuthTokens? = nil) {
        state = Mutex(State(tokens: tokens))
    }

    /// Makes every subsequent operation throw `failure` (pass `nil` to stop failing).
    func simulateFailure(_ failure: KeychainError?) {
        state.withLock { $0.failure = failure }
    }

    var saveCount: Int { state.withLock { $0.saveCount } }

    func load() throws(KeychainError) -> AuthTokens? {
        try state.withLock { (state: inout State) throws(KeychainError) -> AuthTokens? in
            if let failure = state.failure { throw failure }
            return state.tokens
        }
    }

    func save(_ tokens: AuthTokens) throws(KeychainError) {
        try state.withLock { (state: inout State) throws(KeychainError) in
            if let failure = state.failure { throw failure }
            state.tokens = tokens
            state.saveCount += 1
        }
    }

    func clear() throws(KeychainError) {
        try state.withLock { (state: inout State) throws(KeychainError) in
            if let failure = state.failure { throw failure }
            state.tokens = nil
        }
    }
}
#endif
