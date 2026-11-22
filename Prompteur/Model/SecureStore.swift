import Foundation
import Security

/// Accès minimal au Trousseau (les textes y survivent à une réinstallation).
enum SecureStore {
    enum Failure: Error { case status(OSStatus) }

    static func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add.merge(attributes) { $1 }
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw Failure.status(addStatus) }
        } else if status != errSecSuccess {
            throw Failure.status(status)
        }
    }

    enum ReadError: Error { case status(OSStatus) }

    /// Lecture qui distingue « rien d'enregistré » (nil) d'une erreur (exception),
    /// par exemple un Trousseau pas encore déverrouillé.
    static func read(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw ReadError.status(status) }
        return item as? Data
    }

    static func load(key: String) -> Data? {
        (try? read(key: key)) ?? nil
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
