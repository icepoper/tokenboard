import Foundation

// MARK: - 套餐订阅信息

struct SubscriptionInfo {
    let specCode: String        // "standard" / "pro" / "lite"
    let status: String          // "VALID" / "EXPIRED"
    let remainingDays: Int
    let endTime: Date
    let autoRenewFlag: Bool

    var specDisplayName: String {
        switch specCode {
        case "standard": return "Standard"
        case "pro": return "Pro"
        case "lite": return "Lite"
        default: return specCode.capitalized
        }
    }

    var statusDisplayName: String {
        status == "VALID" ? "生效中" : "已过期"
    }

    var endDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: endTime)
    }
}

// MARK: - 实时用量

struct UsageInfo {
    let per5HourPercentage: Double   // 0.0 - 1.0，已用比例
    let per5HourResetTime: Date?    // 字段可能缺失（5h 无消耗时 API 不返回）
    let per1WeekPercentage: Double
    let per1WeekResetTime: Date

    var per5HourRemaining: Double { 1.0 - per5HourPercentage }
    var per1WeekRemaining: Double { 1.0 - per1WeekPercentage }
}

// MARK: - 配额配置

struct QuotaConfig {
    let fiveHour: Double   // 5h 窗口总次数
    let weekly: Double     // 7d 窗口总次数
}

// MARK: - 加油包

struct ResetCard: Identifiable {
    let id: String
    let quota: Double
    let status: String
}

// MARK: - 聚合数据

struct PlanData {
    let subscription: SubscriptionInfo
    let usage: UsageInfo
    let quota: QuotaConfig
    let resetCards: [ResetCard]

    /// 5h 剩余次数
    var fiveHourRemainingCount: Int {
        Int(usage.per5HourRemaining * quota.fiveHour)
    }

    /// 7d 剩余次数
    var weeklyRemainingCount: Int {
        Int(usage.per1WeekRemaining * quota.weekly)
    }

    /// 5h 重置倒计时文字
    var fiveHourResetCountdown: String {
        guard let t = usage.per5HourResetTime else { return "--" }
        return Self.formatCountdown(to: t)
    }

    /// 7d 重置倒计时文字
    var weeklyResetCountdown: String {
        Self.formatCountdown(to: usage.per1WeekResetTime)
    }

    /// 5h 重置时间 (HH:mm)
    var fiveHourResetTimeString: String {
        guard let t = usage.per5HourResetTime else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: t)
    }

    /// 7d 重置时间 (MM-dd HH:mm)
    var weeklyResetTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: usage.per1WeekResetTime)
    }

    /// 最紧张的剩余百分比（用于菜单栏显示）
    var minRemainingPercentage: Double {
        min(usage.per5HourRemaining, usage.per1WeekRemaining)
    }

    /// 菜单栏胶囊文案：5h 剩余 | 7d 剩余
    var remainingPercentText: String {
        "\(Int(usage.per5HourRemaining * 100))% | \(Int(usage.per1WeekRemaining * 100))%"
    }

    /// 格式化倒计时
    static func formatCountdown(to date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "已重置" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            let remainHours = hours % 24
            return "\(days)天\(remainHours)小时"
        } else if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}
