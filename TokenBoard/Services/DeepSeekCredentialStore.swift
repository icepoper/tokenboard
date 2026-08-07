import Foundation
import Combine

/// DeepSeek 平台会话凭证管理：userToken（浏览器 localStorage），Keychain 安全存储
@MainActor
final class DeepSeekCredentialStore: CredentialStoring, ObservableObject {
    /// 全局单例
    static let shared = DeepSeekCredentialStore()

    @Published var status: CredentialStatus = .incomplete

    /// 当前 userToken
    var userToken: String? {
        KeychainHelper.read(key: KeychainHelper.Keys.deepSeekUserToken)
    }

    private init() {
        validate()
    }

    /// 保存凭证（自动清洗：去首尾空白 / 引号，若是 JSON 则提取 token 字段）
    func save(userToken: String) {
        guard let cleaned = Self.normalizeUserToken(userToken) else { return }
        KeychainHelper.save(key: KeychainHelper.Keys.deepSeekUserToken, value: cleaned)
        validate()
    }

    /// 清洗 userToken：兼容直接粘贴 localStorage 原始值（可能带引号或 JSON 包装）
    static func normalizeUserToken(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let data = trimmed.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            if let value = obj as? String {
                return value.isEmpty ? nil : value
            }
            if let dict = obj as? [String: Any] {
                for key in ["value", "token", "access_token", "accessToken", "userToken"] {
                    if let value = dict[key] as? String, !value.isEmpty {
                        return value
                    }
                }
            }
            return nil
        }

        let unquoted: String
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            unquoted = String(trimmed.dropFirst().dropLast())
        } else {
            unquoted = trimmed
        }
        return unquoted.isEmpty ? nil : unquoted
    }

    /// 清除凭证
    func clear() {
        KeychainHelper.delete(key: KeychainHelper.Keys.deepSeekUserToken)
        status = .incomplete
    }

    /// 校验凭证完整性
    func validate() {
        if let t = userToken, !t.isEmpty {
            status = .complete
        } else {
            status = .incomplete
        }
    }

    /// API 返回认证失败（40002 / 40003）时调用
    func markExpired() {
        status = .expired
    }
}
