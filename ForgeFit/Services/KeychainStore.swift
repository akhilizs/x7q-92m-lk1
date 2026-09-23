import Foundation
import Security

/// Stores the user's Gemini API key in the iOS Keychain (never in the app bundle).
enum KeychainStore {
    private static let service = "com.forgefit.app"
    private static let account = "gemini-api-key"

    static var apiKey: String? {
        get {
            // UI tests pass `-uiTestAPIKey <value>` to exercise the chat without a real key.
            if let testKey = UserDefaults.standard.string(forKey: "uiTestAPIKey") { return testKey }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data,
                  let value = String(data: data, encoding: .utf8), !value.isEmpty else { return nil }
            return value
        }
        set {
            let base: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(base as CFDictionary)
            guard let newValue, !newValue.isEmpty else { return }
            var attributes = base
            attributes[kSecValueData as String] = Data(newValue.utf8)
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }
}
