import Foundation

/// DeepSeek 平台 API 客户端
/// 封装 3 个私人接口（get_user_summary / usage/amount / usage/cost），
/// 认证方式为 Authorization: Bearer <userToken>。
actor DeepSeekAPI {
    /// 平台接口根地址
    static let baseURL = URL(string: "https://platform.deepseek.com/api/v0")!

    private var session: URLSession

    init() {
        self.session = Self.makeSession()
    }

    /// 创建 URLSession：监控数据必须实时，禁用一切本地缓存
    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }

    /// 重建会话，丢弃可能已失效的连接池
    func resetSession() {
        let old = session
        session = Self.makeSession()
        old.invalidateAndCancel()
    }

    // MARK: - 公开接口

    /// 获取账户余额（get_user_summary）
    func fetchBalance(userToken: String) async throws -> DeepSeekBalance {
        let url = Self.baseURL.appendingPathComponent("users/get_user_summary")
        let payload: DeepSeekEnvelope<DeepSeekUserSummaryData> = try await get(url: url, userToken: userToken)
        try Self.throwIfError(payload.code, payload.msg)
        guard let summary = payload.data?.bizData else {
            throw APIError.parseError(String(localized: "DeepSeek 余额响应字段缺失"))
        }
        return Self.makeBalance(from: summary)
    }

    /// 获取用量（usage/amount）
    func fetchUsage(userToken: String, month: Int, year: Int) async throws -> DeepSeekAmountData {
        let url = Self.usageURL(path: "usage/amount", month: month, year: year)
        let payload: DeepSeekEnvelope<DeepSeekAmountData> = try await get(url: url, userToken: userToken)
        try Self.throwIfError(payload.code, payload.msg)
        guard let data = payload.data?.bizData else {
            throw APIError.parseError(String(localized: "DeepSeek 用量响应字段缺失"))
        }
        return data
    }

    /// 获取消费（usage/cost）
    func fetchCost(userToken: String, month: Int, year: Int) async throws -> [DeepSeekCostItem] {
        let url = Self.usageURL(path: "usage/cost", month: month, year: year)
        let payload: DeepSeekEnvelope<[DeepSeekCostItem]> = try await get(url: url, userToken: userToken)
        try Self.throwIfError(payload.code, payload.msg)
        return payload.data?.bizData ?? []
    }

    // MARK: - 内部

    private func get<T: Decodable>(url: URL, userToken: String) async throws -> T {
        guard !userToken.isEmpty else {
            throw APIError.credentialMissing
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(String(localized: "非 HTTP 响应"))
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw APIError.authExpired
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func usageURL(path: String, month: Int, year: Int) -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "month", value: String(month)),
            URLQueryItem(name: "year", value: String(year))
        ]
        return components.url!
    }

    /// 错误码判定：40002 / 40003 = 会话失效，其他非 0 = 业务错误
    static func throwIfError(_ code: Int?, _ msg: String?) throws {
        guard let code, code != 0 else { return }
        if code == 40002 || code == 40003 {
            throw APIError.authExpired
        }
        let message = (msg?.isEmpty == false) ? msg! : "DeepSeek 接口错误（code \(code)）"
        throw APIError.parseError(message)
    }

    /// 从 get_user_summary 构建余额：normal=充值，bonus=赠金；优先 CNY
    static func makeBalance(from summary: DeepSeekUserSummaryData) -> DeepSeekBalance {
        let normal = summary.normalWallets?.first(where: { $0.currency == "CNY" })
            ?? summary.normalWallets?.first
        let bonus = summary.bonusWallets?.first(where: { $0.currency == "CNY" })
            ?? summary.bonusWallets?.first
        let currency = normal?.currency ?? bonus?.currency ?? "CNY"
        let total = (normal?.balance ?? 0) + (bonus?.balance ?? 0)
        return DeepSeekBalance(
            isAvailable: total > 0,
            currency: currency,
            totalBalance: total,
            grantedBalance: bonus?.balance ?? 0,
            toppedUpBalance: normal?.balance ?? 0
        )
    }
}

// MARK: - 响应模型（容错解码：错误包不因 data 形状异常而解码失败）

/// 外层信封：code / msg / data（data 含 biz_code / biz_msg / biz_data）
struct DeepSeekEnvelope<BizData: Decodable>: Decodable {
    let code: Int?
    let msg: String?
    let data: DeepSeekBizWrapper<BizData>?

    enum CodingKeys: String, CodingKey { case code, msg, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decodeIfPresent(Int.self, forKey: .code)
        msg = try c.decodeIfPresent(String.self, forKey: .msg)
        data = try? c.decodeIfPresent(DeepSeekBizWrapper<BizData>.self, forKey: .data)
    }
}

/// biz 信封：biz_code / biz_msg / biz_data
struct DeepSeekBizWrapper<BizData: Decodable>: Decodable {
    let bizCode: Int?
    let bizMsg: String?
    let bizData: BizData?

    enum CodingKeys: String, CodingKey {
        case bizCode = "biz_code"
        case bizMsg = "biz_msg"
        case bizData = "biz_data"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bizCode = try c.decodeIfPresent(Int.self, forKey: .bizCode)
        bizMsg = try c.decodeIfPresent(String.self, forKey: .bizMsg)
        bizData = try? c.decodeIfPresent(BizData.self, forKey: .bizData)
    }
}

/// get_user_summary 的 biz_data
struct DeepSeekUserSummaryData: Decodable {
    let normalWallets: [DeepSeekWallet]?
    let bonusWallets: [DeepSeekWallet]?

    enum CodingKeys: String, CodingKey {
        case normalWallets = "normal_wallets"
        case bonusWallets = "bonus_wallets"
    }
}

/// 钱包（balance 可能是数字或字符串）
struct DeepSeekWallet: Decodable {
    let balance: Double
    let currency: String

    enum CodingKeys: String, CodingKey { case balance, currency }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currency = try c.decode(String.self, forKey: .currency)
        if let number = try? c.decode(Double.self, forKey: .balance) {
            balance = number
        } else {
            let value = try c.decode(String.self, forKey: .balance)
            guard let number = Double(value) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .balance,
                    in: c,
                    debugDescription: "DeepSeek wallet balance 非数值"
                )
            }
            balance = number
        }
    }
}

/// usage/amount 的 biz_data
struct DeepSeekAmountData: Decodable {
    /// 各模型当月总计
    let total: [DeepSeekModelUsage]?
    /// 按天按模型明细
    let days: [DeepSeekDayPayload]?
}

/// usage/cost 的 biz_data 单项（数组，按币种）
struct DeepSeekCostItem: Decodable {
    let currency: String?
    let total: [DeepSeekModelUsage]?
    let days: [DeepSeekDayPayload]?
}

/// 模型用量
struct DeepSeekModelUsage: Decodable {
    let model: String?
    let usage: [DeepSeekUsageItem]?
}

/// 单条用量（type: PROMPT_CACHE_HIT_TOKEN / PROMPT_CACHE_MISS_TOKEN / RESPONSE_TOKEN / REQUEST）
struct DeepSeekUsageItem: Decodable {
    let type: String?
    /// 数值可能为字符串
    let amount: String?
}

/// 按天明细
struct DeepSeekDayPayload: Decodable {
    let date: String?
    let data: [DeepSeekModelUsage]?
}

// MARK: - 用量解析（纯函数，便于测试）

/// DeepSeek 用量解析：从 amount / cost 响应构建用量摘要与近 7 天按模型趋势
enum DeepSeekUsageParser {
    /// 北京时间日历（与平台统计口径一致）
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()

    /// yyyy-MM-dd 格式化（北京时间）
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f
    }()

    // MARK: - 汇总辅助

    /// 统计 token 数（缓存命中/未命中输入 + 输出）
    static func tokens(from items: [DeepSeekUsageItem]?) -> Int {
        items?.reduce(0) { sum, item in
            guard let type = item.type?.uppercased(), let amount = Double(item.amount ?? "") else { return sum }
            switch type {
            case "PROMPT_TOKEN", "PROMPT_CACHE_HIT_TOKEN", "PROMPT_CACHE_MISS_TOKEN", "RESPONSE_TOKEN":
                return sum + Int(amount)
            default:
                return sum
            }
        } ?? 0
    }

    /// 统计请求数（REQUEST）
    static func requestCount(from items: [DeepSeekUsageItem]?) -> Int {
        items?.reduce(0) { sum, item in
            guard let type = item.type?.uppercased(), type == "REQUEST", let amount = Double(item.amount ?? "") else { return sum }
            return sum + Int(amount)
        } ?? 0
    }

    /// 统计消费金额（amount 字段求和）
    static func cost(from items: [DeepSeekUsageItem]?) -> Double {
        items?.reduce(0) { sum, item in
            sum + (Double(item.amount ?? "") ?? 0)
        } ?? 0
    }

    static func tokens(from models: [DeepSeekModelUsage]?) -> Int {
        models?.reduce(0) { sum, m in sum + tokens(from: m.usage) } ?? 0
    }

    static func requestCount(from models: [DeepSeekModelUsage]?) -> Int {
        models?.reduce(0) { sum, m in sum + requestCount(from: m.usage) } ?? 0
    }

    static func cost(from models: [DeepSeekModelUsage]?) -> Double {
        models?.reduce(0) { sum, m in sum + cost(from: m.usage) } ?? 0
    }

    // MARK: - 快照构建

    /// 构建今日 / 本月用量摘要（amount 或 cost 均无数据时返回 nil）
    static func makeSummary(
        amount: DeepSeekAmountData?,
        costItems: [DeepSeekCostItem]?,
        now: Date = Date()
    ) -> DeepSeekUsageSummary? {
        guard let amount, amount.total != nil || amount.days != nil else { return nil }
        let todayString = dayFormatter.string(from: now)

        let monthTokens = tokens(from: amount.total)
        let monthRequests = requestCount(from: amount.total)
        let todayTokens = tokens(from: (amount.days ?? []).first { $0.date == todayString }?.data)
        let todayRequests = requestCount(from: (amount.days ?? []).first { $0.date == todayString }?.data)

        let currency = costItems?.first(where: { !($0.currency ?? "").isEmpty })?.currency ?? "CNY"
        let monthCost = costItems?.first.map { cost(from: $0.total) }
        let todayCost: Double?
        if let costItem = costItems?.first,
           let todayDay = (costItem.days ?? []).first(where: { $0.date == todayString }) {
            todayCost = cost(from: todayDay.data)
        } else {
            todayCost = nil
        }
        let topModel = (amount.total ?? [])
            .filter { !($0.model ?? "").isEmpty }
            .max { tokens(from: $0.usage) < tokens(from: $1.usage) }?
            .model

        return DeepSeekUsageSummary(
            todayTokens: todayTokens,
            currentMonthTokens: monthTokens,
            todayCost: todayCost,
            currentMonthCost: monthCost,
            requestCount: todayRequests,
            currentMonthRequestCount: monthRequests,
            topModel: topModel,
            currency: currency
        )
    }

    /// 近 7 天（含今天）按模型分组的 token 用量
    static func last7DaysByModel(
        days: [DeepSeekDayPayload],
        now: Date = Date()
    ) -> [String: [DeepSeekDayUsage]] {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        let startString = dayFormatter.string(from: start)
        let todayString = dayFormatter.string(from: now)

        var result: [String: [DeepSeekDayUsage]] = [:]
        for day in days {
            guard let date = day.date, date >= startString, date <= todayString else { continue }
            for modelUsage in day.data ?? [] {
                guard let model = modelUsage.model, !model.isEmpty else { continue }
                let entry = DeepSeekDayUsage(
                    date: date,
                    model: model,
                    tokens: tokens(from: modelUsage.usage),
                    cost: nil,
                    requestCount: requestCount(from: modelUsage.usage)
                )
                result[model, default: []].append(entry)
            }
        }
        for key in result.keys {
            result[key]?.sort { $0.date < $1.date }
        }
        return result
    }

    // MARK: - 月份 / 跨月判定

    /// 当前月份（北京时间）
    static func currentMonth(now: Date = Date()) -> (month: Int, year: Int) {
        let comps = calendar.dateComponents([.month, .year], from: now)
        return (comps.month ?? 1, comps.year ?? 2026)
    }

    /// 近 7 天窗口是否跨到上个月（需要补拉上月合并）
    static func needsPreviousMonth(now: Date = Date()) -> Bool {
        let (month, year) = currentMonth(now: now)
        let startOfMonth = calendar.date(
            from: DateComponents(year: year, month: month, day: 1)
        )!
        let sevenDaysAgo = calendar.date(
            byAdding: .day,
            value: -6,
            to: calendar.startOfDay(for: now)
        )!
        return sevenDaysAgo < startOfMonth
    }
}
