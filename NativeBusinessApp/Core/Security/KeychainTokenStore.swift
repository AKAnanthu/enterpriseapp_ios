import Foundation
import Security

/// Stores the token bundle as a single generic-password keychain item.
///
/// Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
/// - Readable after the first unlock following a reboot, so a refresh can complete if the app is
///   resumed in the background, while the item stays encrypted until then.
/// - `ThisDeviceOnly`: never included in iCloud Keychain or in backups restored to another device.
/// - Trade-off: `WhenUnlockedThisDeviceOnly` is stricter but makes tokens unreadable while the
///   device is locked. Switch to it if the app never does background work.
///
/// The item is scoped to this app's default keychain access group; no shared access group is used,
/// so other apps cannot read it.
final class KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String

    init(service: String, account: String = "auth-session") {
        self.service = service
        self.account = account
    }

    func load() throws(KeychainError) -> AuthTokens? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw .invalidItemData }
            do {
                return try Self.decoder.decode(AuthTokens.self, from: data)
            } catch {
                throw .invalidItemData
            }
        case errSecItemNotFound:
            return nil
        default:
            throw .unexpectedStatus(status)
        }
    }

    func save(_ tokens: AuthTokens) throws(KeychainError) {
        let data: Data
        do {
            data = try Self.encoder.encode(tokens)
        } catch {
            throw .encodingFailed
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addQuery = baseQuery().merging(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw .unexpectedStatus(addStatus) }
        default:
            throw .unexpectedStatus(updateStatus)
        }
    }

    func clear() throws(KeychainError) {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
