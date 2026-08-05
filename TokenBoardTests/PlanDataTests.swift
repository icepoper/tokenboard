import XCTest
@testable import TokenBoard

/// 数据模型展示逻辑测试
final class PlanDataTests: XCTestCase {

    func testCountdownPastDateShowsReset() {
        let past = Date().addingTimeInterval(-60)
        XCTAssertEqual(PlanData.formatCountdown(to: past), String(localized: "已重置"))
    }

    func testCountdownMinutes() {
        let t = Date().addingTimeInterval(30 * 60 + 30)
        XCTAssertEqual(PlanData.formatCountdown(to: t), String(localized: "\(30)分钟"))
    }

    func testCountdownHoursAndMinutes() {
        let t = Date().addingTimeInterval(4 * 3600 + 50 * 60 + 30)
        XCTAssertEqual(PlanData.formatCountdown(to: t), String(localized: "\(4)小时\(50)分钟"))
    }

    func testCountdownDays() {
        let t = Date().addingTimeInterval(2 * 24 * 3600 + 3 * 3600 + 30)
        XCTAssertEqual(PlanData.formatCountdown(to: t), String(localized: "\(2)天\(3)小时"))
    }

    func testRemainingCount() {
        let usage = UsageInfo(
            per5HourPercentage: 0.5,
            per5HourResetTime: nil,
            per1WeekPercentage: 0.25,
            per1WeekResetTime: Date()
        )
        let quota = QuotaConfig(fiveHour: 3000, weekly: 10000)
        let data = PlanData(
            subscription: SubscriptionInfo(specCode: "standard", status: "VALID", remainingDays: 10, endTime: Date(), autoRenewFlag: false),
            usage: usage,
            quota: quota,
            resetCards: []
        )
        XCTAssertEqual(data.fiveHourRemainingCount, 1500)
        XCTAssertEqual(data.weeklyRemainingCount, 7500)
        XCTAssertEqual(data.minRemainingPercentage, 0.5)
        XCTAssertEqual(data.remainingPercentText, "50% | 75%")
    }

    func testRemainingPercentTextFull() {
        let usage = UsageInfo(
            per5HourPercentage: 0,
            per5HourResetTime: nil,
            per1WeekPercentage: 0,
            per1WeekResetTime: Date()
        )
        let data = PlanData(
            subscription: SubscriptionInfo(specCode: "pro", status: "VALID", remainingDays: 30, endTime: Date(), autoRenewFlag: true),
            usage: usage,
            quota: QuotaConfig(fiveHour: 3000, weekly: 10000),
            resetCards: []
        )
        XCTAssertEqual(data.remainingPercentText, "100% | 100%")
    }
}
