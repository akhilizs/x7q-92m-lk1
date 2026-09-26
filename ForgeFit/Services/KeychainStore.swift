import Foundation
import Security

/// Stores secrets in the iOS Keychain (never in the app bundle): the user's Gemini API
/// key and their account login.
enum KeychainStore {
    private static let service = "com.forgefit.app"

    static var apiKey: String? {
        get {
            // UI tests pass `-uiTestAPIKey <value>` to exercise the chat without a real key.
            if let testKey = UserDefaults.standard.string(forKey: "uiTestAPIKey") { return testKey }
            return data(for: "gemini-api-key").flatMap { String(data: $0, encoding: .utf8) }.flatMap { $0.isEmpty ? nil : $0 }
        }
        set {
            set(newValue.flatMap { $0.isEmpty ? nil : Data($0.utf8) }, for: "gemini-api-key")
        }
    }

    /// The signed-in account, if any.
    static var authSession: AuthSession? {
        get { data(for: "account-session").flatMap { try? JSONDecoder().decode(AuthSession.self, from: $0) } }
        set { set(newValue.flatMap { try? JSONEncoder().encode($0) }, for: "account-session") }
    }

    private static func data(for account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func set(_ value: Data?, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard let value else { return }
        var attributes = base
        attributes[kSecValueData as String] = value
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
