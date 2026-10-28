import Foundation
import Testing
@testable import NativeBusinessApp

/// Exercises the real keychain in the simulator. Each test uses a unique service name.
@Suite("KeychainTokenStore (real keychain)", .serialized)
struct KeychainTokenStoreTests {
    private func makeStore() -> KeychainTokenStore {
        KeychainTokenStore(service: "tests.\(UUID().uuidString)")
    }

    @Test func savesLoadsUpdatesAndClears() throws {
        let store = makeStore()
        defer { try? store.clear() }

        #expect(try store.load() == nil)

        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        let tokens = AuthTokens(accessToken: "a-1", refreshToken: "r-1", expiresAt: expiry)
        try store.save(tokens)
        #expect(try store.load() == tokens)

        let rotated = AuthTokens(accessToken: "a-2", refreshToken: "r-2", expiresAt: nil)
        try store.save(rotated)
        #expect(try store.load() == rotated)

        try store.clear()
        #expect(try store.load() == nil)
        try store.clear() // Clearing twice is not an error.
    }

    @Test func storesAreIsolatedByService() throws {
        let first = makeStore()
        let second = makeStore()
        defer {
            try? first.clear()
            try? second.clear()
        }
        try first.save(Fixtures.tokens)
        #expect(try second.load() == nil)
    }

    @Test func freshInstallGuardClearsStaleCredentialsOnce() throws {
        let store = makeStore()
        defer { try? store.clear() }
        let suiteName = "tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try store.save(Fixtures.tokens)
        FreshInstallGuard.clearStaleCredentialsIfNeeded(tokenStore: store, defaults: defaults)
        #expect(try store.load() == nil)

        try store.save(Fixtures.tokens)
        FreshInstallGuard.clearStaleCredentialsIfNeeded(tokenStore: store, defaults: defaults)
        #expect(try store.load() == Fixtures.tokens)
    }
}
