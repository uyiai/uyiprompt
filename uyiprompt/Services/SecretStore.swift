import Foundation
import Security

protocol SecretStore: AnyObject {
    func set(_ value: String, account: String)
    func get(account: String) -> String?
    func delete(account: String)
}

enum SecretStores {
    private final class Box: @unchecked Sendable {
        let lock = NSLock()
        var store: any SecretStore = KeychainSecretStore()
    }

    private static let box = Box()

    static var current: any SecretStore {
        get {
            box.lock.lock()
            defer { box.lock.unlock() }
            return box.store
        }
        set {
            box.lock.lock()
            box.store = newValue
            box.lock.unlock()
        }
    }
}

final class MemorySecretStore: SecretStore {
    private var items: [String: String] = [:]

    func set(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            items.removeValue(forKey: account)
        } else {
            items[account] = trimmed
        }
    }

    func get(account: String) -> String? {
        items[account]
    }

    func delete(account: String) {
        items.removeValue(forKey: account)
    }
}

final class KeychainSecretStore: SecretStore {
    private let service = "app.uyiprompt.apikey"

    func set(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        delete(account: account)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}