import XCTest
@testable import TokenBoard

/// DeepSeek 余额 / 用量 / 消费解析、错误映射、跨月判定测试
final class DeepSeekAPITests: XCTestCase {

    // MARK: - 余额解析

    /// 余额字段为字符串时正常解析
    func testBalanceParsingWithStringBalances() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "biz_code": 0,
            "biz_data": {
              "normal_wallets": [{"balance": "110.00", "currency": "CNY"}],
              "bonus_wallets": [{"balance": "10.00", "currency": "CNY"}]
            }
          }
        }
        """
        let payload = try JSONDecoder().decode(DeepSeekEnvelope<DeepSeekUserSummaryData>.self, from: Data(json.utf8))
        let balance = DeepSeekAPI.makeBalance(from: payload.data!.bizData!)
        XCTAssertEqual(balance.totalBalance, 120.0, accuracy: 1e-9)
        XCTAssertEqual(balance.toppedUpBalance, 110.0, accuracy: 1e-9)
        XCTAssertEqual(balance.grantedBalance, 10.0, accuracy: 1e-9)
        XCTAssertEqual(balance.currency, "CNY")
        XCTAssertTrue(balance.isAvailable)
    }

    /// 余额字段为数字时正常解析
    func testBalanceParsingWithNumberBalances() throws {
        let json = """
        {
          "code": 0,
          "data": { "biz_data": {
            "normal_wallets": [{"balance": 5.5, "currency": "USD"}],
            "bonus_wallets": []
          } }
        }
        """
        let payload = try JSONDecoder().decode(DeepSeekEnvelope<DeepSeekUserSummaryData>.self, from: Data(json.utf8))
        let balance = DeepSeekAPI.makeBalance(from: payload.data!.bizData!)
        XCTAssertEqual(balance.currency, "USD")
        XCTAssertEqual(balance.totalBalance, 5.5, accuracy: 1e-9)
        XCTAssertTrue(balance.isAvailable)
    }

    /// 余额为零时不可用
    func testBalanceZeroIsNotAvailable() throws {
        let json = """
        { "code": 0, "data": { "biz_data": { "normal_wallets": [{"balance": 0, "currency": "CNY"}], "bonus_wallets": [] } } }
        """
        let payload = try JSONDecoder().decode(DeepSeekEnvelope<DeepSeekUserSummaryData>.self, from: Data(json.utf8))
        let balance = DeepSeekAPI.makeBalance(from: payload.data!.bizData!)
        XCTAssertFalse(balance.isAvailable)
    }

    // MARK: - 用量摘要解析

    /// 今日 / 本月 tokens、请求数、topModel
    func testUsageSummaryParsing() throws {
        let json = """
        {
          "code": 0,
          "data": { "biz_data": {
            "total": [
              { "model": "deepseek-chat", "usage": [
                {"type": "PROMPT_CACHE_HIT_TOKEN", "amount": "100"},
                {"type": "PROMPT_CACHE_MISS_TOKEN", "amount": "200"},
                {"type": "RESPONSE_TOKEN", "amount": "300"},
                {"type": "REQUEST", "amount": "5"}
              ]},
              { "model": "deepseek-reasoner", "usage": [
                {"type": "PROMPT_TOKEN", "amount": "100"},
                {"type": "PROMPT_CACHE_MISS_TOKEN", "amount": "500"},
                {"type": "RESPONSE_TOKEN", "amount": "700"},
                {"type": "REQUEST", "amount": "3"}
              ]}
            ],
            "days": [
              { "date": "2026-08-07", "data": [
                { "model": "deepseek-chat", "usage": [
                  {"type": "PROMPT_CACHE_MISS_TOKEN", "amount": "50"},
                  {"type": "RESPONSE_TOKEN", "amount": "80"},
                  {"type": "REQUEST", "amount": "2"}
                ]}
              ]}
            ]
          } }
        }
        """
        let payload = try JSONDecoder().decode(DeepSeekEnvelope<DeepSeekAmountData>.self, from: Data(json.utf8))
        let amount = payload.data!.bizData!

        // 用固定 now 保证今天 = 2026-08-07
        let now = DeepSeekUsageParser.dayFormatter.date(from: "2026-08-07")!
        let summary = DeepSeekUsageParser.makeSummary(amount: amount, costItems: nil, now: now)

        XCTAssertEqual(summary?.todayTokens, 130)          // 50 + 80
        XCTAssertEqual(summary?.currentMonthTokens, 1900)  // 100+200+300 + 100+500+700
        XCTAssertEqual(summary?.requestCount, 2)
        XCTAssertEqual(summary?.currentMonthRequestCount, 8) // 5 + 3
        XCTAssertEqual(summary?.topModel, "deepseek-reasoner")
    }

    /// amount 无数据时摘要为 nil
    func testUsageSummaryNilWhenEmpty() {
        let summary = DeepSeekUsageParser.makeSummary(amount: nil, costItems: nil)
        XCTAssertNil(summary)
    }

    /// 消费解析（monthCost / todayCost）
    func testCostParsing() throws {
        let json = """
        {
          "code": 0,
          "data": { "biz_data": [
            { "currency": "CNY",
              "total": [ { "model": "deepseek-chat", "usage": [{"type": "PROMPT_CACHE_MISS_TOKEN", "amount": "1.25"}] } ],
              "days": [ { "date": "2026-08-07", "data": [
                { "model": "deepseek-chat", "usage": [{"type": "RESPONSE_TOKEN", "amount": "0.50"}] }
              ] } ]
            }
          ] }
        }
        """
        let payload = try JSONDecoder().decode(DeepSeekEnvelope<[DeepSeekCostItem]>.self, from: Data(json.utf8))
        let cost = payload.data!.bizData!
        let now = DeepSeekUsageParser.dayFormatter.date(from: "2026-08-07")!
        let amount = DeepSeekAmountData(total: [], days: [])
        let summary = DeepSeekUsageParser.makeSummary(amount: amount, costItems: cost, now: now)
        XCTAssertEqual(summary?.currency, "CNY")
        XCTAssertEqual(summary?.currentMonthCost ?? -1, 1.25, accuracy: 1e-9)
        XCTAssertEqual(summary?.todayCost ?? -1, 0.50, accuracy: 1e-9)
    }

    // MARK: - 近 7 天按模型趋势

    /// 只保留近 7 天，按模型分组并按日期排序
    func testLast7DaysByModel() throws {
        // 构造 10 天数据（2026-08-01 ~ 2026-08-10）
        var days: [DeepSeekDayPayload] = []
        let formatter = DeepSeekUsageParser.dayFormatter
        for day in 1...10 {
            let date = formatter.string(from: formatter.date(from: "2026-08-\(String(format: "%02d", day))")!)
            days.append(DeepSeekDayPayload(date: date, data: [
                DeepSeekModelUsage(model: "deepseek-chat", usage: [
                    DeepSeekUsageItem(type: "RESPONSE_TOKEN", amount: "\(day * 100)")
                ])
            ]))
        }
        let now = formatter.date(from: "2026-08-10")!
        let result = DeepSeekUsageParser.last7DaysByModel(days: days, now: now)

        let chat = result["deepseek-chat"]
        XCTAssertEqual(chat?.count, 7, "应只保留近 7 天（08-04 ~ 08-10）")
        XCTAssertEqual(chat?.first?.date, "2026-08-04")
        XCTAssertEqual(chat?.last?.date, "2026-08-10")
        XCTAssertEqual(chat?.first?.tokens, 400)
    }

    // MARK: - 错误码映射

    /// 40002 / 40003 = 会话失效
    func testAuthExpiredCodes() {
        XCTAssertThrowsError(try DeepSeekAPI.throwIfError(40002, nil)) { error in
            guard case APIError.authExpired = error else {
                return XCTFail("40002 应映射为 authExpired，实际 \(error)")
            }
        }
        XCTAssertThrowsError(try DeepSeekAPI.throwIfError(40003, "session invalid")) { error in
            guard case APIError.authExpired = error else {
                return XCTFail("40003 应映射为 authExpired，实际 \(error)")
            }
        }
    }

    /// 其他非 0 code = 业务错误，带 msg
    func testBusinessErrorCode() {
        XCTAssertThrowsError(try DeepSeekAPI.throwIfError(50000, "internal error")) { error in
            guard case APIError.parseError(let msg) = error else {
                return XCTFail("应抛 parseError，实际 \(error)")
            }
            XCTAssertEqual(msg, "internal error")
        }
    }

    /// code 为 0 或 nil 不抛错
    func testZeroCodeNoThrow() throws {
        try DeepSeekAPI.throwIfError(0, nil)
        try DeepSeekAPI.throwIfError(nil, nil)
    }

    // MARK: - 跨月合并判定

    /// 月初（8 月 3 日）近 7 天跨到 7 月 → 需要补拉上月
    func testNeedsPreviousMonthEarlyInMonth() {
        let now = DeepSeekUsageParser.dayFormatter.date(from: "2026-08-03")!
        XCTAssertTrue(DeepSeekUsageParser.needsPreviousMonth(now: now))
    }

    /// 月中（8 月 10 日）近 7 天不跨月 → 无需补拉
    func testNeedsPreviousMonthMidMonth() {
        let now = DeepSeekUsageParser.dayFormatter.date(from: "2026-08-10")!
        XCTAssertFalse(DeepSeekUsageParser.needsPreviousMonth(now: now))
    }

    /// 当前月份取北京时间
    func testCurrentMonth() {
        let now = DeepSeekUsageParser.dayFormatter.date(from: "2026-08-15")!
        let (month, year) = DeepSeekUsageParser.currentMonth(now: now)
        XCTAssertEqual(month, 8)
        XCTAssertEqual(year, 2026)
    }

    // MARK: - userToken 清洗

    @MainActor
    func testNormalizeUserTokenPlain() {
        XCTAssertEqual(DeepSeekCredentialStore.normalizeUserToken("  abc123  "), "abc123")
    }

    @MainActor
    func testNormalizeUserTokenQuoted() {
        XCTAssertEqual(DeepSeekCredentialStore.normalizeUserToken("\"abc123\""), "abc123")
        XCTAssertEqual(DeepSeekCredentialStore.normalizeUserToken("'abc123'"), "abc123")
    }

    @MainActor
    func testNormalizeUserTokenJSON() {
        XCTAssertEqual(DeepSeekCredentialStore.normalizeUserToken("{\"userToken\":\"abc123\"}"), "abc123")
        XCTAssertEqual(DeepSeekCredentialStore.normalizeUserToken("{\"value\":\"tok\"}"), "tok")
        XCTAssertEqual(DeepSeekCredentialStore.normalizeUserToken("\"direct\""), "direct")
    }

    @MainActor
    func testNormalizeUserTokenEmpty() {
        XCTAssertNil(DeepSeekCredentialStore.normalizeUserToken(""))
        XCTAssertNil(DeepSeekCredentialStore.normalizeUserToken("   "))
    }
}
