import Foundation
import Security

enum KeychainStore {
    private static let releaseService = "dev.yusukeshib.mend"
    private static let developmentService = "dev.yusukeshib.mend.dev"
    private static let migrationKey = "didMigrateMendAPIKeys"

    private static var legacyServices: [String] {
        switch service {
        case releaseService:
            return ["dev.yusukeshib.heelp", "com.yusukeshibata.jogen"]
        case developmentService:
            return ["dev.yusukeshib.heelp.dev", "dev.yusukeshib.heelp"]
        default:
            return []
        }
    }

    private static var service: String {
        Bundle.main.bundleIdentifier ?? developmentService
    }

    static func migrateLegacyAPIKeysIfNeeded(defaults: UserDefaults = .standard) {
        let legacyServices = Self.legacyServices
        guard !legacyServices.isEmpty, !defaults.bool(forKey: migrationKey) else { return }
        defaults.set(true, forKey: migrationKey)

        for provider in AIProvider.allCases {
            if let data = apiKeyData(for: provider, service: service) {
                replaceAPIKeyData(data, for: provider, service: service)
            } else if let data = legacyServices.lazy.compactMap({
                apiKeyData(for: provider, service: $0)
            }).first {
                replaceAPIKeyData(data, for: provider, service: service)
            }
        }
    }

    private static func apiKeyData(for provider: AIProvider, service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    private static func replaceAPIKeyData(
        _ data: Data,
        for provider: AIProvider,
        service: String
    ) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount
        ]
        let deleteStatus = SecItemDelete(query as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else { return }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func apiKey(for provider: AIProvider) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return "" }
        return value
    }

    static func setAPIKey(_ value: String, for provider: AIProvider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount
        ]

        if value.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.status(status)
            }
            return
        }

        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8)
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = Data(value.utf8)
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.status(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.status(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .status(let status):
            return SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
        }
    }
}
