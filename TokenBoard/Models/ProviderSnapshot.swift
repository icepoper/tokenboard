import Foundation

/// 服务商监控快照（活动服务商的当前数据）
enum ProviderSnapshot {
    case qianwen(QianwenSnapshot)
    case deepseek(DeepSeekSnapshot)
}

/// 千问快照：包装套餐 / 用量 / 配额 / 加油包与趋势数据
struct QianwenSnapshot {
    let planData: PlanData
    let trend: UsageTrend?
    let trendError: String?
}

/// DeepSeek 快照：余额 + 用量摘要 + 近 7 天按模型趋势
struct DeepSeekSnapshot {
    /// 余额（nil = 拉取失败或未配置）
    let balance: DeepSeekBalance?
    /// 今日 / 本月用量摘要（nil = 暂无数据）
    let usage: DeepSeekUsageSummary?
    /// 模型 -> 近 7 天按天用量（日期 yyyy-MM-dd）
    let dailyByModel: [String: [DeepSeekDayUsage]]
    /// 最近一次失败原因（nil = 正常）
    let errorMessage: String?
}

/// DeepSeek 余额
struct DeepSeekBalance {
    let isAvailable: Bool
    let currency: String
    let totalBalance: Double
    let grantedBalance: Double
    let toppedUpBalance: Double
}

/// DeepSeek 用量摘要（今日 / 本月）
struct DeepSeekUsageSummary {
    let todayTokens: Int
    let currentMonthTokens: Int
    let todayCost: Double?
    let currentMonthCost: Double?
    let requestCount: Int
    let currentMonthRequestCount: Int
    let topModel: String?
    let currency: String
}

/// DeepSeek 单日单模型用量
struct DeepSeekDayUsage {
    /// 日期（yyyy-MM-dd）
    let date: String
    let model: String
    let tokens: Int
    let cost: Double?
    let requestCount: Int
}
