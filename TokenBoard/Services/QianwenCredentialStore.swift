import Foundation
import Combine

/// 千问凭证管理：Cookie + sec_token，Keychain 安全存储
@MainActor
final class QianwenCredentialStore: CredentialStoring, ObservableObject {
    /// 全局单例
    static let shared = QianwenCredentialStore()

    @Published var status: CredentialStatus = .incomplete

    /// 当前 Cookie
    var cookie: String? {
        KeychainHelper.read(key: KeychainHelper.Keys.cookie)
    }

    /// 当前 sec_token
    var secToken: String? {
        KeychainHelper.read(key: KeychainHelper.Keys.secToken)
    }

    private init() {
        validate()
    }

    /// 保存凭证
    func save(cookie: String, secToken: String) {
        KeychainHelper.save(key: KeychainHelper.Keys.cookie, value: cookie)
        KeychainHelper.save(key: KeychainHelper.Keys.secToken, value: secToken)
        validate()
    }

    /// 清除凭证
    func clear() {
        KeychainHelper.delete(key: KeychainHelper.Keys.cookie)
        KeychainHelper.delete(key: KeychainHelper.Keys.secToken)
        status = .incomplete
    }

    /// 校验凭证完整性
    func validate() {
        let c = cookie
        let t = secToken
        if let c = c, !c.isEmpty, let t = t, !t.isEmpty {
            status = .complete
        } else {
            status = .incomplete
        }
    }

    /// API 返回认证失败时调用
    func markExpired() {
        status = .expired
    }
}
