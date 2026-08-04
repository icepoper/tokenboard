import Foundation

// MARK: - 最近 7 天用量趋势

/// 单日用量数据
struct UsageDay: Identifiable, Equatable {
    /// 当天（API 点位时间戳为当天结束时刻，减 1 秒落到当天 23:59:59）
    let date: Date
    let totalTokens: Double
    let inputTokens: Double
    let outputTokens: Double
    let cachedTokens: Double

    var id: Date { date }

    /// 非缓存输入 tokens（输入中未命中缓存的部分）
    var uncachedInputTokens: Double { max(inputTokens - cachedTokens, 0) }

    /// 缓存命中率（缓存 tokens / 输入 tokens），无输入时为 0
    var cacheHitRate: Double {
        inputTokens > 0 ? cachedTokens / inputTokens : 0
    }

    /// 日期标签 MM-dd（固定北京时间，与接口统计口径一致，不受本机时区影响）
    var dayLabel: String {
        Self.dayLabelFormatter.string(from: date)
    }

    static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f
    }()
}

/// 最近 7 天用量趋势
struct UsageTrend: Equatable {
    let days: [UsageDay]

    /// 本周总 tokens
    var weekTotal: Double { days.reduce(0) { $0 + $1.totalTokens } }

    /// 人性化数字：1234 → 1.2K，49994714 → 50.0M，2.5e9 → 2.5B
    static func humanize(_ value: Double) -> String {
        switch abs(value) {
        case 1_000_000_000...:
            return String(format: "%.1fB", value / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", value / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", value / 1_000)
        default:
            return String(Int(value))
        }
    }
}

// MARK: - 从接口响应构建

extension UsageTrend {

    /// 从 getModelMonitorDataWithOss 响应构建趋势
    /// 只解析 aggMethod == "sum" 的按天序列；cumsum（周累计）与无关指标忽略
    init(response: UsageTrendResponseData) {
        struct DayAccumulator {
            var total: Double = 0
            var input: Double = 0
            var output: Double = 0
            var cached: Double = 0
        }

        var byTimestamp: [Int64: DayAccumulator] = [:]

        for series in response.originData where series.aggMethod == "sum" {
            guard let usageType = series.labels.usageType else { continue }
            for point in series.points {
                let key = Int64(point.timestamp)
                var acc = byTimestamp[key] ?? DayAccumulator()
                switch usageType {
                case "total_tokens": acc.total = point.value
                case "input_tokens": acc.input = point.value
                case "output_tokens": acc.output = point.value
                case "cached_tokens": acc.cached = point.value
                default: break
                }
                byTimestamp[key] = acc
            }
        }

        // 点位 timestamp 是当天结束时刻（次日 00:00 北京时间），减 1 秒落到当天
        days = byTimestamp
            .sorted { $0.key < $1.key }
            .map { key, acc in
                UsageDay(
                    date: Date(timeIntervalSince1970: TimeInterval(key) / 1000 - 1),
                    totalTokens: acc.total,
                    inputTokens: acc.input,
                    outputTokens: acc.output,
                    cachedTokens: acc.cached
                )
            }
    }
}
