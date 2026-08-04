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
