import Foundation

/// 千问工作台 API 客户端
/// 封装 5 个逆向接口的调用逻辑
actor QianwenAPI {

    // MARK: - 常量

    private static let businessBaseURL = "https://cs-data.qianwenai.com/data/api.json"
    private static let bssBaseURL = "https://platform-home.qianwenai.com/data/api.json"
    private static let timeoutInterval: TimeInterval = 10

    private static let cornerstoneParam: [String: String] = [
        "domain": "platform.qianwenai.com",
        "consoleSite": "QIANWENAI",
        "console": "ONE_CONSOLE",
        "xsp_lang": "zh-CN",
        "protocol": "V2",
        "productCode": "p_efm"
    ]

    private var session: URLSession

    /// 会话重建次数（诊断与测试用）
    private(set) var sessionResetCount = 0

    init() {
        self.session = Self.makeSession()
    }

    /// 创建 URLSession：监控数据必须实时，禁用一切本地缓存
    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.timeoutInterval
        config.timeoutIntervalForResource = Self.timeoutInterval
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }

    /// 重建会话，丢弃可能已失效的连接池。
    /// 代理重载 / 节点切换 / 网络切换后，旧的 keep-alive 隧道可能半死：
    /// 请求写得进去但永远等不到响应，导致所有轮询持续超时。重建会话可强制建立新连接。
    func resetSession() {
        let old = session
        session = Self.makeSession()
        sessionResetCount += 1
        old.invalidateAndCancel()
    }

    /// 业务 API URL（附带毫秒级 cache-buster，防止中间层按 URL 缓存响应）
    static func businessURL(api: String) -> URL {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        return URL(string: businessBaseURL + "?product=sfm_bailian&action=BroadScopeAspnGateway&api=\(api)&_=\(ts)")!
    }

    // MARK: - 公开方法

    /// 拉取所有数据（quota 依赖 subscription 返回的套餐等级）
    func fetchAll(cookie: String, secToken: String) async throws -> PlanData {
        async let subscriptionTask = fetchSubscription(cookie: cookie, secToken: secToken)
        async let usageTask = fetchUsage(cookie: cookie, secToken: secToken)
        async let cardsTask = fetchResetCards(cookie: cookie, secToken: secToken)

        let (sub, use, cardList) = try await (subscriptionTask, usageTask, cardsTask)
        let quota = try await fetchQuotaConfig(cookie: cookie, secToken: secToken, specCode: sub.specCode)
        return PlanData(subscription: sub, usage: use, quota: quota, resetCards: cardList)
    }

    /// 获取套餐订阅信息
    func fetchSubscription(cookie: String, secToken: String) async throws -> SubscriptionInfo {
        let params: [String: Any] = [
            "Api": "zeldaHttp.apikeyMgr./tokenplan/personal/api/v2/subscription",
            "Data": [
                "commodityCode": "sfm_tokenplansolo_public_cn",
                "cornerstoneParam": Self.cornerstoneParam
            ] as [String: Any],
            "V": "1.0"
        ]

        let responseData: SubscriptionResponseData = try await callBusinessAPI(
            api: "zeldaHttp.apikeyMgr.%2Ftokenplan%2Fpersonal%2Fapi%2Fv2%2Fsubscription",
            params: params,
            cookie: cookie,
            secToken: secToken
        )

        guard let specCode = responseData.specCode,
              let status = responseData.status,
              let remainingDays = responseData.remainingDays,
              let endTimeTs = responseData.endTime else {
            throw APIError.parseError(String(localized: "subscription 响应字段缺失"))
        }

        return SubscriptionInfo(
            specCode: specCode,
            status: status,
            remainingDays: remainingDays,
            endTime: Date(timeIntervalSince1970: endTimeTs / 1000),
            autoRenewFlag: responseData.autoRenewFlag ?? false
        )
    }

    /// 获取实时用量
    func fetchUsage(cookie: String, secToken: String) async throws -> UsageInfo {
        let params: [String: Any] = [
            "Api": "zeldaHttp.apikeyMgr./tokenplan/personal/api/v2/usage",
            "Data": ["cornerstoneParam": Self.cornerstoneParam] as [String: Any],
            "V": "1.0"
        ]

        let responseData: UsageResponseData = try await callBusinessAPI(
            api: "zeldaHttp.apikeyMgr.%2Ftokenplan%2Fpersonal%2Fapi%2Fv2%2Fusage",
            params: params,
            cookie: cookie,
            secToken: secToken
        )

        return try Self.makeUsageInfo(from: responseData)
    }

    /// 构造 UsageInfo：usage 接口可能只返回部分字段（无消耗的窗口不返回百分比 / 重置时间），
    /// 缺失字段按未知（nil）处理，仅当两个窗口的百分比都缺失时才视为解析失败。
    static func makeUsageInfo(from data: UsageResponseData) throws -> UsageInfo {
        guard data.per5HourPercentage != nil || data.per1WeekPercentage != nil else {
            throw APIError.parseError(String(localized: "usage 响应字段缺失"))
        }
        return UsageInfo(
            per5HourPercentage: data.per5HourPercentage,
            per5HourResetTime: data.per5HourResetTime.map { Date(timeIntervalSince1970: $0 / 1000) },
            per1WeekPercentage: data.per1WeekPercentage,
            per1WeekResetTime: data.per1WeekResetTime.map { Date(timeIntervalSince1970: $0 / 1000) }
        )
    }

    /// 获取配额配置
    func fetchQuotaConfig(cookie: String, secToken: String, specCode: String) async throws -> QuotaConfig {
        let params: [String: Any] = [
            "Api": "zeldaHttp.apikeyMgr./tokenplan/personal/api/v2/quota-config",
            "Data": ["cornerstoneParam": Self.cornerstoneParam] as [String: Any],
            "V": "1.0"
        ]

        let responseData: QuotaConfigResponseData = try await callBusinessAPI(
            api: "zeldaHttp.apikeyMgr.%2Ftokenplan%2Fpersonal%2Fapi%2Fv2%2Fquota-config",
            params: params,
            cookie: cookie,
            secToken: secToken
        )

        let tier: QuotaConfigResponseData.QuotaTier?
        switch specCode {
        case "standard": tier = responseData.standard
        case "pro": tier = responseData.pro
        case "lite": tier = responseData.lite
        default: tier = responseData.standard
        }

        guard let t = tier else {
            throw APIError.parseError(String(localized: "quota-config 中未找到 \(specCode) 等级"))
        }

        return QuotaConfig(
            fiveHour: t.five_hour ?? 3000,
            weekly: t.weekly ?? 10000
        )
    }

    /// 获取加油包列表
    func fetchResetCards(cookie: String, secToken: String) async throws -> [ResetCard] {
        let params: [String: Any] = [
            "Api": "zeldaHttp.apikeyMgr./tokenplan/personal/api/v2/reset-card/list",
            "Data": ["cornerstoneParam": Self.cornerstoneParam] as [String: Any],
            "V": "1.0"
        ]

        // reset-card 返回的 data 是数组，需要特殊处理
        let url = Self.businessURL(api: "zeldaHttp.apikeyMgr.%2Ftokenplan%2Fpersonal%2Fapi%2Fv2%2Freset-card%2Flist")
        let request = try buildRequest(url: url, params: params, cookie: cookie, secToken: secToken)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        // 解析外层结构（与主解析共用兼容逻辑）
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let innerData: Any
        do {
            innerData = try Self.extractInnerData(from: json)
        } catch APIError.authExpired {
            throw APIError.authExpired
        } catch {
            return []
        }

        // data 字段是数组
        guard let cardArray = innerData as? [[String: Any]] else {
            return []
        }

        return cardArray.enumerated().map { idx, card in
            ResetCard(
                id: card["id"] as? String ?? "\(idx)",
                quota: card["quota"] as? Double ?? 0,
                status: card["status"] as? String ?? ""
            )
        }
    }

    /// 获取最近 7 天用量趋势（工作台「用量详情」按天统计口径）
    func fetchUsageTrend(cookie: String, secToken: String) async throws -> UsageTrend {
        let api = "zeldaEasy.bailian-telemetry.platform-model.getModelMonitorDataWithOss"
        let window = Self.trendTimeWindow()

        let params: [String: Any] = [
            "Api": api,
            "Data": [
                "reqDTO": [
                    "productMode": "TokenPlanPersonal",
                    "startTime": window.startTime,
                    "endTime": window.endTime,
                    "step": 86400,
                    "metricFilters": [["aggMethod": "sum", "metricName": "model_usage"]]
                ] as [String: Any],
                "cornerstoneParam": Self.cornerstoneParam
            ] as [String: Any],
            "V": "1.0"
        ]

        let responseData: UsageTrendResponseData = try await callBusinessAPI(
            api: api,
            params: params,
            cookie: cookie,
            secToken: secToken
        )
        return UsageTrend(response: responseData)
    }

    /// 趋势查询时间窗（毫秒）：endTime = 明天 00:00 北京时间，startTime = endTime - 7 天。
    /// 服务端按北京时间的自然日分桶，窗口必须对齐，否则首尾两天数据会缺失或错位。
    static func trendTimeWindow(now: Date = Date()) -> (startTime: Int64, endTime: Int64) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let startOfToday = calendar.startOfDay(for: now)
        let endTime = startOfToday.addingTimeInterval(86400)
        let startTime = endTime.addingTimeInterval(-7 * 86400)
        return (Int64(startTime.timeIntervalSince1970 * 1000), Int64(endTime.timeIntervalSince1970 * 1000))
    }

    // MARK: - 内部方法

    /// 通用业务 API 调用
    private func callBusinessAPI<T: Decodable>(
        api: String,
        params: [String: Any],
        cookie: String,
        secToken: String
    ) async throws -> T {
        let url = Self.businessURL(api: api)
        let request = try buildRequest(url: url, params: params, cookie: cookie, secToken: secToken)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        return try parseBusinessResponse(data)
    }

    /// 构造 POST 请求
    func buildRequest(
        url: URL,
        params: [String: Any],
        cookie: String,
        secToken: String
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://platform.qianwenai.com", forHTTPHeaderField: "Origin")
        request.setValue("https://platform.qianwenai.com/home/billing/subscription/token-plan-individual", forHTTPHeaderField: "Referer")

        // 构造 form body
        var formFields: [String] = []
        formFields.append("product=\(url.queryValue(for: "product") ?? "sfm_bailian")")
        formFields.append("action=\(url.queryValue(for: "action") ?? "BroadScopeAspnGateway")")
        formFields.append("sec_token=\(secToken.urlEncoded)")
        formFields.append("region=cn-beijing")

        let paramsJSON = try JSONSerialization.data(withJSONObject: params)
        let paramsString = String(data: paramsJSON, encoding: .utf8) ?? "{}"
        formFields.append("params=\(paramsString.urlEncoded)")

        request.httpBody = formFields.joined(separator: "&").data(using: .utf8)
        return request
    }

    /// 校验 HTTP 响应
    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(String(localized: "非 HTTP 响应"))
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw APIError.authExpired
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode)
        }
    }

    /// 解析业务 API 响应（嵌套 JSON 结构）
    private func parseBusinessResponse<T: Decodable>(_ data: Data) throws -> T {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let innerData = try Self.extractInnerData(from: json)

        // 将 innerData 重新序列化为 Data 再解码
        let innerDataBytes = try JSONSerialization.data(withJSONObject: innerData)
        return try JSONDecoder().decode(T.self, from: innerDataBytes)
    }

    /// 提取业务响应中的 data.DataV2.data.data。
    /// 网关不同后端节点的成功标记不一致：有的返回 code=="SUCCESS"，
    /// 有的只返回 success==true（遥测类接口实测如此），三种判定兼容，
    /// 否则会出现"有时能解析、有时报解析错误"的随机故障。
    static func extractInnerData(from json: [String: Any]?) throws -> Any {
        guard let outerData = json?["data"] as? [String: Any],
              let dataV2 = outerData["DataV2"] as? [String: Any] else {
            throw APIError.parseError(String(localized: "响应缺少 DataV2 结构"))
        }

        // 检查认证错误
        if let ret = dataV2["ret"] as? [String],
           let firstRet = ret.first,
           firstRet.contains("FAIL_SYS_SESSION_EXPIRED") || firstRet.contains("FAIL_SYS_TOKEN_EXOIRED") {
            throw APIError.authExpired
        }

        guard let innerWrapper = dataV2["data"] as? [String: Any] else {
            throw APIError.parseError(String(localized: "响应缺少 data 层"))
        }

        let codeOK = (innerWrapper["code"] as? String) == "SUCCESS"
        let successOK = innerWrapper["success"] as? Bool == true
        let retOK = (dataV2["ret"] as? [String])?.first?.hasPrefix("SUCCESS") == true

        guard codeOK || successOK || retOK else {
            let errorMsg = outerData["errorMsg"] as? String ?? ""
            throw APIError.parseError(errorMsg.isEmpty ? String(localized: "接口返回失败状态") : errorMsg)
        }

        guard let innerData = innerWrapper["data"] else {
            throw APIError.parseError(String(localized: "响应缺少数据体"))
        }
        return innerData
    }
}

// MARK: - 辅助扩展

private extension URL {
    func queryValue(for key: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == key })?
            .value
    }
}

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
