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
            return "网络错误: \(error.localizedDescription)"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .parseError(let msg):
            return "解析错误: \(msg)"
        case .authExpired:
            return "登录已过期，请重新粘贴 Cookie"
        case .credentialMissing:
            return "凭证未配置"
        case .timeout:
            return "请求超时"
        case .unknown(let msg):
            return msg
        }
    }
}
