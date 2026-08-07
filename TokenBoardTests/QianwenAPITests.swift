import XCTest
@testable import TokenBoard

/// API 客户端的请求构造与会话管理测试
final class QianwenAPITests: XCTestCase {

    /// URL 必须带 cache-buster，防止中间层（CDN/代理）按 URL 缓存响应
    func testBusinessURLContainsCacheBuster() {
        let url1 = QianwenAPI.businessURL(api: "zeldaHttp.apikeyMgr.%2Ftokenplan%2Fpersonal%2Fapi%2Fv2%2Fusage")
        let query = URLComponents(url: url1, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let names = query.map(\.name)
        XCTAssertTrue(names.contains("product"))
        XCTAssertTrue(names.contains("action"))
        XCTAssertTrue(names.contains("api"))
        XCTAssertTrue(names.contains("_"), "缺少 cache-buster 参数 _")
    }

    /// 连续两次构造的 URL cache-buster 应不同（毫秒级时间戳）
    func testCacheBusterChangesBetweenCalls() async {
        func buster() -> String? {
            let url = QianwenAPI.businessURL(api: "x")
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "_" })?.value
        }
        let a = buster()
        // 确保毫秒时间戳推进
        try? await Task.sleep(nanoseconds: 5_000_000)
        let b = buster()
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertNotEqual(a, b)
    }

    /// POST 请求体必须包含 sec_token 与 params 表单字段
    func testBuildRequestFormBody() async throws {
        let api = QianwenAPI()
        let url = QianwenAPI.businessURL(api: "zeldaHttp.apikeyMgr.%2Ftokenplan%2Fpersonal%2Fapi%2Fv2%2Fusage")
        let request = try await api.buildRequest(
            url: url,
            params: ["Api": "test", "V": "1.0"],
            cookie: "cna=fake; ticket=fake",
            secToken: "tok en%123"
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "cna=fake; ticket=fake")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")

        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("sec_token=tok%20en%25123"), "sec_token 未正确编码: \(body)")
        XCTAssertTrue(body.contains("params="))
        XCTAssertTrue(body.contains("region=cn-beijing"))
    }

    /// resetSession 应递增重建计数
    func testResetSessionIncrementsCount() async {
        let api = QianwenAPI()
        let before = await api.sessionResetCount
        await api.resetSession()
        let after = await api.sessionResetCount
        XCTAssertEqual(after, before + 1)
    }
}

// MARK: - 业务响应解析兼容测试

extension QianwenAPITests {

    /// 形态一：传统 code=="SUCCESS"（subscription/usage 等接口）
    func testExtractInnerDataWithCodeSuccess() throws {
        let json: [String: Any] = [
            "data": [
                "DataV2": [
                    "ret": ["SUCCESS::接口调用成功"],
                    "data": ["code": "SUCCESS", "data": ["foo": 1]]
                ]
            ]
        ]
        let inner = try QianwenAPI.extractInnerData(from: json) as? [String: Any]
        XCTAssertEqual(inner?["foo"] as? Int, 1)
    }

    /// 形态二：遥测接口只返回 success==true，无 code 字段（v0.1.3 线上故障形态）
    func testExtractInnerDataWithSuccessBoolOnly() throws {
        let json: [String: Any] = [
            "data": [
                "errorMsg": "",
                "DataV2": [
                    "ret": ["SUCCESS::接口调用成功"],
                    "data": [
                        "success": true,
                        "requestId": "x",
                        "data": ["originData": []]
                    ]
                ]
            ]
        ]
        let inner = try QianwenAPI.extractInnerData(from: json) as? [String: Any]
        XCTAssertNotNil(inner?["originData"])
    }

    /// 认证过期必须抛 authExpired，不能被兼容逻辑吞掉
    func testExtractInnerDataAuthExpired() {
        let json: [String: Any] = [
            "data": [
                "DataV2": [
                    "ret": ["FAIL_SYS_SESSION_EXPIRED::会话过期"],
                    "data": ["success": true, "data": ["a": 1]]
                ]
            ]
        ]
        XCTAssertThrowsError(try QianwenAPI.extractInnerData(from: json)) { error in
            guard case APIError.authExpired = error else {
                return XCTFail("应抛 authExpired，实际 \(error)")
            }
        }
    }

    /// 明确失败状态（success==false 且无 code）应抛 parseError 且文案非空
    func testExtractInnerDataFailureStatus() {
        let json: [String: Any] = [
            "data": [
                "DataV2": [
                    "ret": ["UNKNOWN::未知"],
                    "data": ["success": false, "data": ["a": 1]]
                ]
            ]
        ]
        XCTAssertThrowsError(try QianwenAPI.extractInnerData(from: json)) { error in
            guard case APIError.parseError(let msg) = error else {
                return XCTFail("应抛 parseError，实际 \(error)")
            }
            XCTAssertFalse(msg.isEmpty, "错误文案不能为空")
        }
    }
}

// MARK: - usage 响应宽松解析测试（v0.1.5：接口可能只返回部分字段）

extension QianwenAPITests {

    /// 稀疏响应：只有 per1WeekPercentage（当前线上实际返回形态），不应报错
    func testMakeUsageInfoSparseWeeklyOnly() throws {
        let data = UsageResponseData(
            per5HourPercentage: nil,
            per5HourResetTime: nil,
            per1WeekPercentage: 0.0,
            per1WeekResetTime: nil
        )
        let usage = try QianwenAPI.makeUsageInfo(from: data)
        XCTAssertEqual(usage.per5HourPercentage, nil)
        XCTAssertEqual(usage.per5HourResetTime, nil)
        XCTAssertEqual(usage.per1WeekPercentage, 0.0)
        XCTAssertEqual(usage.per1WeekResetTime, nil)
        XCTAssertEqual(usage.per1WeekRemaining, 1.0)
        XCTAssertNil(usage.per5HourRemaining)
    }

    /// 完整响应：所有字段正常映射
    func testMakeUsageInfoFullData() throws {
        let data = UsageResponseData(
            per5HourPercentage: 0.0009973083333333333,
            per5HourResetTime: 1784813220000,
            per1WeekPercentage: 0.0003014725,
            per1WeekResetTime: 1785234900000
        )
        let usage = try QianwenAPI.makeUsageInfo(from: data)
        XCTAssertEqual(usage.per5HourPercentage ?? -1, 0.0009973083333333333, accuracy: 1e-12)
        XCTAssertEqual(usage.per5HourResetTime?.timeIntervalSince1970 ?? -1, 1784813220, accuracy: 1e-6)
        XCTAssertEqual(usage.per1WeekPercentage ?? -1, 0.0003014725, accuracy: 1e-12)
        XCTAssertEqual(usage.per1WeekResetTime?.timeIntervalSince1970 ?? -1, 1785234900, accuracy: 1e-6)
    }

    /// 两个窗口百分比都缺失：视为解析失败
    func testMakeUsageInfoThrowsWhenAllMissing() {
        let data = UsageResponseData(
            per5HourPercentage: nil,
            per5HourResetTime: nil,
            per1WeekPercentage: nil,
            per1WeekResetTime: nil
        )
        XCTAssertThrowsError(try QianwenAPI.makeUsageInfo(from: data)) { error in
            guard case APIError.parseError(let msg) = error else {
                return XCTFail("应抛 parseError，实际 \(error)")
            }
            XCTAssertFalse(msg.isEmpty)
        }
    }
}
