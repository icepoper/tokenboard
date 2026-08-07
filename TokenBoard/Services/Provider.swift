import Foundation
import Combine

/// 服务商标识
enum ProviderID: String, CaseIterable, Identifiable {
    case qianwen
    case deepseek

    var id: String { rawValue }

    /// 服务商显示名称
    var displayName: String {
        switch self {
        case .qianwen: return "千问"
        case .deepseek: return "DeepSeek"
        }
    }
}

/// 服务商抽象：菜单栏 / 弹出面板 / 轮询服务只依赖本协议。
/// 各服务商实现自己的凭证管理、API 客户端与轮询逻辑。
@MainActor
protocol Provider: AnyObject, Identifiable {
    /// 服务商标识
    var id: ProviderID { get }
    /// 服务商显示名称
    var displayName: String { get }
    /// 凭证状态
    var credentialStatus: CredentialStatus { get }
    /// 监控快照（nil = 尚无数据）
    var snapshot: ProviderSnapshot? { get }
    /// 轮询状态
    var state: PollingState { get }
    /// 是否处于持续失败状态（UI 展示错误提示）
    var isFailing: Bool { get }
    /// 最近一次失败原因（nil = 正常）
    var lastError: String? { get }
    /// 最近成功更新时间（nil = 尚未更新）
    var lastUpdated: Date? { get }
    /// 轮询间隔（秒）
    var pollingInterval: Int { get set }
    /// 变化通知（供 ProviderManager 转发到 UI）
    var objectWillChange: ObservableObjectPublisher { get }

    /// 启动轮询
    func start()
    /// 停止轮询
    func stop()
    /// 手动刷新
    func refresh() async
    /// 凭证变化后重启轮询
    func restartIfNeeded()
}
