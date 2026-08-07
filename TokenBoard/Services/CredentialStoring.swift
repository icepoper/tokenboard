import Foundation

/// 凭证状态
enum CredentialStatus {
    case complete       // 凭证齐全
    case incomplete     // 缺少某项
    case expired        // API 返回认证失败
}

/// 凭证存储协议：各服务商凭证的通用行为
@MainActor
protocol CredentialStoring: AnyObject {
    /// 当前凭证状态
    var status: CredentialStatus { get }
    /// 清除凭证
    func clear()
    /// API 返回认证失败时标记为失效
    func markExpired()
}
