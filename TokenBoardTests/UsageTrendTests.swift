import XCTest
@testable import TokenBoard

/// 最近 7 天用量趋势：响应解析 / 格式化 / 时间窗逻辑测试
final class UsageTrendTests: XCTestCase {

    // MARK: - Fixture（裁剪自真实 getModelMonitorDataWithOss 响应）

    private static let dayTimestamps: [Int64] = [
        1785340800000, 1785427200000, 1785513600000, 1785600000000,
        1785686400000, 1785772800000, 1785859200000
    ]

    /// 构造一条序列的 JSON
    private static func seriesJSON(
        aggMethod: String,
        usageType: String,
        unit: String,
        values: [String],
        timestamps: [Int64]? = nil
    ) -> String {
        let ts = timestamps ?? dayTimestamps
        let points = zip(values, ts)
            .map { "{\"value\":\($0),\"timestamp\":\($1)}" }
            .joined(separator: ",")
        return "{\"aggMethod\":\"\(aggMethod)\",\"metricName\":\"model_usage\",\"step\":86400,\"points\":[\(points)],\"labels\":{\"unit\":\"\(unit)\",\"usage_type\":\"\(usageType)\"}}"
    }

    private static let fixtureJSON: String = {
        let series = [
            // 按天序列（应解析）
            seriesJSON(aggMethod: "sum", usageType: "total_tokens", unit: "tokens",
                       values: ["0.0", "1814482.0", "49994714", "23148374", "22171223", "0.0", "41111716"]),
            // 周累计（应忽略，否则总量会翻倍）
            seriesJSON(aggMethod: "cumsum", usageType: "total_tokens", unit: "tokens",
                       values: ["138240509"], timestamps: [1785859200000]),
            // 非 token 指标（应忽略）
            seriesJSON(aggMethod: "sum", usageType: "image_count", unit: "个数",
                       values: ["0.0", "1.0", "0.0", "0.0", "0.0", "0.0", "0.0"]),
            seriesJSON(aggMethod: "sum", usageType: "output_tokens", unit: "tokens",
                       values: ["0.0", "31685.0", "728106.0", "277193.0", "847476.0", "0.0", "452040.0"]),
            seriesJSON(aggMethod: "sum", usageType: "input_tokens", unit: "tokens",
                       values: ["0.0", "1782797.0", "49196352", "22826821", "21318863", "0.0", "40454641"]),
            // 含科学计数法 1.031616E+7，验证 Double 解码
            seriesJSON(aggMethod: "sum", usageType: "cached_tokens", unit: "tokens",
                       values: ["0.0", "1372544.0", "28306304", "10289024", "1.031616E+7", "0.0", "30020736"])
        ]
        return "{\"originData\":[\(series.joined(separator: ","))]}"
    }()

    private func parseFixture() throws -> UsageTrend {
        let data = Data(Self.fixtureJSON.utf8)
        let response = try JSONDecoder().decode(UsageTrendResponseData.self, from: data)
        return UsageTrend(response: response)
    }

    // MARK: - 解析

    func testParseSampleResponse() throws {
        let trend = try parseFixture()

        XCTAssertEqual(trend.days.count, 7)
        // 周总量 = 按天 total_tokens 之和，与接口 cumsum 值一致
        XCTAssertEqual(trend.weekTotal, 138240509, accuracy: 0.5)

        // 点位时间戳是当天结束时刻，减 1 秒后应为 07-29 ~ 08-04
        XCTAssertEqual(trend.days.first?.dayLabel, "07-29")
        XCTAssertEqual(trend.days.last?.dayLabel, "08-04")

        // 最后一天明细
        let last = trend.days[6]
        XCTAssertEqual(last.totalTokens, 41111716, accuracy: 0.5)
        XCTAssertEqual(last.inputTokens, 40454641, accuracy: 0.5)
        XCTAssertEqual(last.outputTokens, 452040, accuracy: 0.5)
        XCTAssertEqual(last.cachedTokens, 30020736, accuracy: 0.5)
        XCTAssertEqual(last.uncachedInputTokens, 40454641 - 30020736, accuracy: 0.5)
        XCTAssertEqual(last.cacheHitRate, 30020736 / 40454641, accuracy: 0.0001)
    }

    /// cumsum 周累计与非 token 指标不能污染按天数据
    func testIgnoresCumsumAndUnknownMetrics() throws {
        let trend = try parseFixture()
        // image_count 有一天值为 1，如果误解析会导致某天 total 异常
        XCTAssertEqual(trend.days[1].totalTokens, 1814482, accuracy: 0.5)
        // 科学计数法点位（08-02）
        XCTAssertEqual(trend.days[4].cachedTokens, 10316160, accuracy: 0.5)
    }

    /// 空响应 / 无数据
    func testEmptyResponse() {
        let response = UsageTrendResponseData(originData: [])
        let trend = UsageTrend(response: response)
        XCTAssertTrue(trend.days.isEmpty)
        XCTAssertEqual(trend.weekTotal, 0)
    }

    // MARK: - 日期标签（必须固定北京时间，不受本机时区影响）

    func testDayLabelUsesBeijingTime() {
        // 1785859200000 = 2026-08-05 00:00 北京时间，减 1 秒 = 08-04
        let date = Date(timeIntervalSince1970: 1785859200000 / 1000 - 1)
        let day = UsageDay(date: date, totalTokens: 0, inputTokens: 0, outputTokens: 0, cachedTokens: 0)
        XCTAssertEqual(day.dayLabel, "08-04")
    }

    // MARK: - 人性化数字

    func testHumanize() {
        XCTAssertEqual(UsageTrend.humanize(0), "0")
        XCTAssertEqual(UsageTrend.humanize(999), "999")
        XCTAssertEqual(UsageTrend.humanize(1234), "1.2K")
        XCTAssertEqual(UsageTrend.humanize(49994714), "50.0M")
        XCTAssertEqual(UsageTrend.humanize(138240509), "138.2M")
        XCTAssertEqual(UsageTrend.humanize(2_500_000_000), "2.5B")
    }

    // MARK: - 时间窗

    /// 与真实请求 payload 对齐：2026-08-04（北京时间）内任意时刻，
    /// endTime = 08-05 00:00 = 1785859200000，startTime = endTime - 7 天
    func testTrendTimeWindowMatchesAPIPayload() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: 18, minute: 30))!

        let window = QianwenAPI.trendTimeWindow(now: now)
        XCTAssertEqual(window.endTime, 1785859200000)
        XCTAssertEqual(window.startTime, 1785254400000)
        XCTAssertEqual(window.endTime - window.startTime, 7 * 86400 * 1000)
    }

    /// 跨天边界：08-05 凌晨 00:30 查询，窗口应已滚动到 08-06 结束
    func testTrendTimeWindowRollover() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 0, minute: 30))!

        let window = QianwenAPI.trendTimeWindow(now: now)
        XCTAssertEqual(window.endTime, 1785859200000 + 86400 * 1000)
    }
}
