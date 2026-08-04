import XCTest
@testable import TokenBoard

/// 连续失败计数器的决策逻辑测试
final class FailureTrackerTests: XCTestCase {

    func testFirstFailureTriggersRetryOnly() {
        var tracker = FailureTracker()
        let d = tracker.recordFailure()
        XCTAssertTrue(d.shouldRetry)
        XCTAssertFalse(d.shouldResetSession)
        XCTAssertFalse(d.isError)
        XCTAssertEqual(tracker.consecutiveFailures, 1)
    }

    func testSecondFailureResetsSession() {
        var tracker = FailureTracker()
        _ = tracker.recordFailure()
        let d = tracker.recordFailure()
        XCTAssertTrue(d.shouldResetSession)
        XCTAssertFalse(d.shouldRetry)
        XCTAssertFalse(d.isError)
        XCTAssertTrue(tracker.isFailing)
    }

    func testThirdFailureEntersErrorState() {
        var tracker = FailureTracker()
        _ = tracker.recordFailure()
        _ = tracker.recordFailure()
        let d = tracker.recordFailure()
        XCTAssertTrue(d.isError)
        XCTAssertEqual(tracker.consecutiveFailures, 3)
    }

    func testSuccessResetsCounters() {
        var tracker = FailureTracker()
        _ = tracker.recordFailure()
        _ = tracker.recordFailure()
        tracker.recordSuccess()
        XCTAssertEqual(tracker.consecutiveFailures, 0)
        XCTAssertFalse(tracker.isFailing)

        // 成功后的下一次失败应重新从 1 计数
        let d = tracker.recordFailure()
        XCTAssertTrue(d.shouldRetry)
        XCTAssertFalse(d.shouldResetSession)
    }

    func testIsFailingThreshold() {
        var tracker = FailureTracker()
        XCTAssertFalse(tracker.isFailing)
        _ = tracker.recordFailure()
        XCTAssertFalse(tracker.isFailing)
        _ = tracker.recordFailure()
        XCTAssertTrue(tracker.isFailing)
    }
}
