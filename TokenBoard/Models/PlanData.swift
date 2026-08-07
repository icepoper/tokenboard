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
        status == "VALID" ? String(localized: "生效中") : String(localized: "已过期")
    }

    var endDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: endTime)
    }
}

// MARK: - 实时用量

struct UsageInfo {
    /// 5h 窗口已用比例（0.0 - 1.0）；API 可能不返回（无消耗 / 新账号），nil = 未知
    let per5HourPercentage: Double?
    /// 5h 重置时间；字段可能缺失
    let per5HourResetTime: Date?
    /// 7d 窗口已用比例（0.0 - 1.0）；可能缺失
    let per1WeekPercentage: Double?
    /// 7d 重置时间；可能缺失
    let per1WeekResetTime: Date?

    var per5HourRemaining: Double? { per5HourPercentage.map { 1.0 - $0 } }
    var per1WeekRemaining: Double? { per1WeekPercentage.map { 1.0 - $0 } }
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

    /// 5h 剩余次数（用量未知时为 nil）
    var fiveHourRemainingCount: Int? {
        guard let remaining = usage.per5HourRemaining else { return nil }
        return Int(remaining * quota.fiveHour)
    }

    /// 7d 剩余次数（用量未知时为 nil）
    var weeklyRemainingCount: Int? {
        guard let remaining = usage.per1WeekRemaining else { return nil }
        return Int(remaining * quota.weekly)
    }

    /// 5h 重置倒计时文字
    var fiveHourResetCountdown: String {
        guard let t = usage.per5HourResetTime else { return "--" }
        return Self.formatCountdown(to: t)
    }

    /// 7d 重置倒计时文字（未知时显示 --）
    var weeklyResetCountdown: String {
        guard let t = usage.per1WeekResetTime else { return "--" }
        return Self.formatCountdown(to: t)
    }

    /// 5h 重置时间 (HH:mm)
    var fiveHourResetTimeString: String {
        guard let t = usage.per5HourResetTime else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: t)
    }

    /// 7d 重置时间 (MM-dd HH:mm)；未知时显示 --
    var weeklyResetTimeString: String {
        guard let t = usage.per1WeekResetTime else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: t)
    }

    /// 最紧张的剩余百分比（用于菜单栏显示）；两个窗口都未知时按 1（满额）显示
    var minRemainingPercentage: Double {
        let remainings = [usage.per5HourRemaining, usage.per1WeekRemaining].compactMap { $0 }
        return remainings.min() ?? 1
    }

    /// 菜单栏胶囊文案：5h 剩余 | 7d 剩余（未知窗口显示 --）
    var remainingPercentText: String {
        let p5h = usage.per5HourRemaining.map { "\(Int($0 * 100))%" } ?? "--"
        let p1w = usage.per1WeekRemaining.map { "\(Int($0 * 100))%" } ?? "--"
        return "\(p5h) | \(p1w)"
    }

    /// 格式化倒计时
    static func formatCountdown(to date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return String(localized: "已重置") }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            let remainHours = hours % 24
            return String(localized: "\(days)天\(remainHours)小时")
        } else if hours > 0 {
            return String(localized: "\(hours)小时\(minutes)分钟")
        } else {
            return String(localized: "\(minutes)分钟")
        }
    }
}
