import Foundation

// MARK: - 通用外层响应

struct OuterResponse<T: Decodable>: Decodable {
    let code: String?
    let data: OuterData<T>?
    let httpStatusCode: String?
    let successResponse: Bool?
}

struct OuterData<T: Decodable>: Decodable {
    let DataV2: DataV2<T>?
    // BSS API 使用不同的结构
    let Data: BSSData?
    let Message: String?
    let Code: String?
    let Success: Bool?
}

struct DataV2<T: Decodable>: Decodable {
    let data: InnerData<T>?
}

struct InnerData<T: Decodable>: Decodable {
    let code: String?
    let msg: String?
    let data: T?
    let success: Bool?
}

// MARK: - Subscription 响应

struct SubscriptionResponseData: Decodable {
    let instanceCode: String?
    let specCode: String?
    let remainingDays: Int?
    let startTime: Double?
    let endTime: Double?
    let autoRenewFlag: Bool?
    let status: String?
}

// MARK: - Usage 响应

struct UsageResponseData: Decodable {
    let per5HourPercentage: Double?
    let per5HourResetTime: Double?
    let per1WeekPercentage: Double?
    let per1WeekResetTime: Double?
}

// MARK: - Quota Config 响应

struct QuotaConfigResponseData: Decodable {
    let standard: QuotaTier?
    let pro: QuotaTier?
    let lite: QuotaTier?

    struct QuotaTier: Decodable {
        let five_hour: Double?
        let weekly: Double?
    }
}

// MARK: - Reset Card 响应

struct ResetCardResponseData: Decodable {
    // 加油包列表，可能为空
}

// MARK: - BSS 实例响应

struct BSSData: Decodable {
    let InstanceList: [BSSInstance]?
    let TotalCount: Int?
}

struct BSSInstance: Decodable {
    let InstanceID: String?
    let Status: String?
    let EndTime: String?
    let RenewStatus: String?
}
