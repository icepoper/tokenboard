import Foundation
import Combine

/// DeepSeek 服务商：轮询余额 / 用量 / 消费，构建 DeepSeekSnapshot。
/// 近 7 天跨月时自动补拉上月数据合并。
@MainActor
final class DeepSeekProvider: Provider, ObservableObject {
    static let shared = DeepSeekProvider()

    let id: ProviderID = .deepseek
    let displayName = "DeepSeek"

    @Published private(set) var snapshot: ProviderSnapshot?
    @Published private(set) var state: PollingState = .idle
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    var credentialStatus: CredentialStatus { credentials.status }
    var isFailing: Bool { tracker.isFailing }

    /// 轮询间隔（秒），与全局设置共用同一 UserDefaults 键
    var pollingInterval: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: "pollingInterval")
            return value == 0 ? 60 : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "pollingInterval")
            restartIfNeeded()
        }
    }

    private let api: DeepSeekAPI
    private let credentials: DeepSeekCredentialStore
    private var pollingTask: Task<Void, Never>?
    private var tracker = FailureTracker()

    init(api: DeepSeekAPI = DeepSeekAPI(), credentials: DeepSeekCredentialStore? = nil) {
        self.api = api
        self.credentials = credentials ?? .shared
    }

    // MARK: - DeepSeek 凭证操作（设置页使用）

    func saveCredential(userToken: String) {
        credentials.save(userToken: userToken)
    }

    func clearCredential() {
        credentials.clear()
    }

    // MARK: - Provider 生命周期

    func start() {
        guard credentialStatus == .complete else {
            state = .idle
            return
        }
        stop()
        state = .polling
        tracker.recordSuccess()

        pollingTask = Task { [weak self] in
            // 首次立即拉取
            await self?.doFetch()

            while !Task.isCancelled {
                guard let self = self else { return }
                let interval = UInt64(self.pollingInterval) * 1_000_000_000
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled else { return }
                await self.doFetch()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        if state != .error {
            state = .idle
        }
    }

    func refresh() async {
        state = .refreshing
        if tracker.consecutiveFailures > 0 {
            // 处于失败状态时先丢弃旧连接池
            await api.resetSession()
        }
        await doFetch()
        if credentialStatus == .complete, !tracker.isFailing {
            state = .polling
        }
    }

    func restartIfNeeded() {
        if credentialStatus == .complete {
            start()
        } else {
            stop()
            snapshot = nil
            lastError = nil
        }
    }

    // MARK: - 内部

    private func doFetch() async {
        guard let token = credentials.userToken, !token.isEmpty else {
            state = .idle
            return
        }

        do {
            let data = try await fetchAll(userToken: token)
            applySuccess(data)
            if let balance = data.balance {
                await NotificationHelper.shared.checkAndNotifyDeepSeek(balance: balance)
            }
            if state != .refreshing {
                state = .polling
            }
        } catch let error as APIError {
            if case .authExpired = error {
                credentials.markExpired()
                stop()
                state = .idle
                return
            }
            await handleFailure(Self.describe(error))
        } catch {
            await handleFailure(Self.describe(error))
        }
    }

    /// 拉取余额 + 用量（必要时跨月合并）+ 消费
    private func fetchAll(userToken: String) async throws -> DeepSeekSnapshot {
        async let balanceTask = api.fetchBalance(userToken: userToken)
        async let usageTask = fetchUsageWithPreviousMonth(userToken: userToken)
        async let costTask = fetchCurrentMonthCost(userToken: userToken)

        let (balance, usage, cost) = try await (balanceTask, usageTask, costTask)

        let summary = DeepSeekUsageParser.makeSummary(amount: usage.currentMonth, costItems: cost)
        let daily = DeepSeekUsageParser.last7DaysByModel(days: usage.allDays)
        return DeepSeekSnapshot(
            balance: balance,
            usage: summary,
            dailyByModel: daily,
            errorMessage: nil
        )
    }

    private struct UsageData {
        let currentMonth: DeepSeekAmountData?
        let allDays: [DeepSeekDayPayload]
    }

    /// 拉当前月用量；近 7 天起点早于本月 1 号时补拉上月合并
    private func fetchUsageWithPreviousMonth(userToken: String) async throws -> UsageData {
        let (month, year) = DeepSeekUsageParser.currentMonth()
        let current = try await api.fetchUsage(userToken: userToken, month: month, year: year)
        var allDays = current.days ?? []

        if DeepSeekUsageParser.needsPreviousMonth() {
            let startOfMonth = DeepSeekUsageParser.calendar.date(
                from: DateComponents(year: year, month: month, day: 1)
            )!
            let prev = DeepSeekUsageParser.calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
            let prevMonth = DeepSeekUsageParser.calendar.component(.month, from: prev)
            let prevYear = DeepSeekUsageParser.calendar.component(.year, from: prev)
            if let prevData = try? await api.fetchUsage(userToken: userToken, month: prevMonth, year: prevYear) {
                allDays = (prevData.days ?? []) + allDays
            }
        }
        return UsageData(currentMonth: current, allDays: allDays)
    }

    private func fetchCurrentMonthCost(userToken: String) async throws -> [DeepSeekCostItem]? {
        let (month, year) = DeepSeekUsageParser.currentMonth()
        return try await api.fetchCost(userToken: userToken, month: month, year: year)
    }

    private func applySuccess(_ data: DeepSeekSnapshot) {
        snapshot = .deepseek(data)
        lastUpdated = Date()
        lastError = nil
        tracker.recordSuccess()
        // 成功拉取说明凭证有效，若此前标记过期则恢复
        credentials.validate()
    }

    /// 失败处理：记录错误、按决策重建连接池 / 重试 / 进入错误状态
    func handleFailure(_ message: String) async {
        lastError = message
        let decision = tracker.recordFailure()

        if decision.shouldResetSession {
            await api.resetSession()
        }

        if decision.shouldRetry {
            // 单次失败，5 秒后重试一次
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let token = credentials.userToken, !token.isEmpty else { return }
            do {
                let data = try await fetchAll(userToken: token)
                applySuccess(data)
                return
            } catch {
                lastError = Self.describe(error)
                _ = tracker.recordFailure()
                if tracker.consecutiveFailures >= tracker.maxConsecutiveFailures {
                    state = .error
                }
                return
            }
        }

        if decision.isError {
            state = .error
        }
    }

    /// 错误描述：APIError 用中文用户文案，其余保留系统原始信息（英文，便于排查）
    static func describe(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? "Unknown error"
        }
        return error.localizedDescription
    }
}
