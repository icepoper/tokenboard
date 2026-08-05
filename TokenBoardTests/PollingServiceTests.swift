import XCTest
@testable import TokenBoard

/// 轮询服务的失败处理逻辑测试
@MainActor
final class PollingServiceTests: XCTestCase {

    /// 连续失败 3 次应进入 error 状态并暴露错误信息
    func testConsecutiveFailuresEnterErrorState() async {
        let service = PollingService()
        service.credentialManager = nil

        await service.handleFailure("network error: timeout")
        XCTAssertEqual(service.consecutiveFailures, 1)
        XCTAssertNotEqual(service.state, .error)
        XCTAssertEqual(service.lastError, "network error: timeout")
        XCTAssertTrue(service.isFailing == false)

        await service.handleFailure("network error: timeout")
        XCTAssertTrue(service.isFailing)

        await service.handleFailure("network error: timeout")
        XCTAssertEqual(service.state, .error)
        XCTAssertEqual(service.consecutiveFailures, 3)
    }

    /// 连续失败 2 次后应触发会话重建（丢弃失效连接池）
    func testSessionResetOnConsecutiveFailures() async {
        let api = QianwenAPI()
        let service = PollingService(api: api)

        await service.handleFailure("err")
        let countAfterFirst = await api.sessionResetCount
        await service.handleFailure("err")
        let countAfterSecond = await api.sessionResetCount

        XCTAssertGreaterThan(countAfterSecond, countAfterFirst, "第二次连续失败后应重建会话")
    }

    /// describe 应保留 APIError 的用户文案
    func testDescribeAPIError() {
        XCTAssertEqual(PollingService.describe(APIError.authExpired), String(localized: "登录已过期，请重新粘贴 Cookie"))
        XCTAssertTrue(PollingService.describe(APIError.httpError(statusCode: 500)).contains("500"))
    }
}
