import Foundation
import Security

/// macOS Keychain 封装，安全存储凭证
enum KeychainHelper {
    private static let service = "com.tokenboard.credentials"

    /// 保存字符串到 Keychain
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // 先删除已有的
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    /// 从 Keychain 读取字符串
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// 从 Keychain 删除
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - 便捷键名

    enum Keys {
        static let cookie = "qianwen_cookie"
        static let secToken = "qianwen_sec_token"
        static let deepSeekUserToken = "deepseek_user_token"
    }
}
