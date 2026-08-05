import Foundation

/// API 调用错误类型
enum APIError: LocalizedError {
    case networkError(Error)
    case httpError(statusCode: Int)
    case parseError(String)
    case authExpired
    case credentialMissing
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return String(localized: "网络错误: \(error.localizedDescription)")
        case .httpError(let code):
            return String(localized: "HTTP 错误: \(code)")
        case .parseError(let msg):
            return String(localized: "解析错误: \(msg)")
        case .authExpired:
            return String(localized: "登录已过期，请重新粘贴 Cookie")
        case .credentialMissing:
            return String(localized: "凭证未配置")
        case .timeout:
            return String(localized: "请求超时")
        case .unknown(let msg):
            return msg
        }
    }
}
