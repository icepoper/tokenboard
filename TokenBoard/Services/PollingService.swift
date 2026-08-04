import Foundation
import Combine

/// 轮询状态
enum PollingState {
    case idle           // 未启动
    case polling        // 正常轮询中
    case refreshing     // 手动刷新中
    case error          // 连接异常
}

/// 后台轮询服务
@MainActor
final class PollingService: ObservableObject {
    /// 全局单例
    static let shared = PollingService()

    @Published var planData: PlanData?
    @Published var state: PollingState = .idle
    @Published var lastUpdated: Date?
    /// 最近一次失败原因（nil 表示正常）。用于 UI 展示，避免静默显示旧数据
    @Published var lastError: String?
    /// 最近 7 天用量趋势（辅助信息，拉取失败时保留旧数据）
    @Published var trend: UsageTrend?
    /// 趋势最近一次失败原因（nil = 正常）。用于 UI 展示，趋势失败不再完全静默
    @Published var trendError: String?

    /// 趋势缓存有效期（秒）：按天粒度的数据不需要每轮轮询都拉
    private let trendCacheTTL: TimeInterval = 30 * 60
    private var trendFetchedAt: Date?

    /// 轮询间隔（秒），持久化到 UserDefaults
    var pollingInterval: Int {
        get { UserDefaults.standard.integer(forKey: "pollingInterval").nonZero ?? 60 }
        set {
            UserDefaults.standard.set(newValue, forKey: "pollingInterval")
            restartIfNeeded()
        }
    }

    private let api: QianwenAPI
    private var pollingTask: Task<Void, Never>?
    private var tracker = FailureTracker()

    /// 连续失败次数（UI 与测试可读）
    var consecutiveFailures: Int { tracker.consecutiveFailures }
    /// 是否处于持续失败状态（UI 据此展示错误提示）
    var isFailing: Bool { tracker.isFailing }

    weak var credentialManager: CredentialManager?

    init(api: QianwenAPI = QianwenAPI()) {
        self.api = api
    }

    // MARK: - 生命周期

    /// 启动轮询
    func start() {
        guard credentialManager?.status == .complete else {
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

    /// 停止轮询
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        if state != .error {
            state = .idle
        }
    }

    /// 手动刷新
    func refresh() async {
        state = .refreshing
        if tracker.consecutiveFailures > 0 {
            // 处于失败状态时先丢弃旧连接池，保证手动刷新走新连接
            await api.resetSession()
        }
        await doFetch(forceTrend: true)
        if credentialManager?.status == .complete, !tracker.isFailing {
            state = .polling
        }
    }

    /// 凭证变化后重启
    func restartIfNeeded() {
        if credentialManager?.status == .complete {
            start()
        } else {
            stop()
            planData = nil
            trend = nil
            trendError = nil
            trendFetchedAt = nil
            lastError = nil
        }
    }

    // MARK: - 内部

    private func doFetch(forceTrend: Bool = false) async {
        guard let cm = credentialManager,
              let cookie = cm.cookie, !cookie.isEmpty,
              let secToken = cm.secToken, !secToken.isEmpty else {
            state = .idle
            return
        }

        do {
            let data = try await api.fetchAll(cookie: cookie, secToken: secToken)
            applySuccess(data)
            await fetchTrendIfNeeded(cookie: cookie, secToken: secToken, force: forceTrend)
            await NotificationHelper.shared.checkAndNotify(usage: data.usage)

            if state != .refreshing {
                state = .polling
            }
        } catch let error as APIError {
            if case .authExpired = error {
                cm.markExpired()
                stop()
                state = .idle
                return
            }
            await handleFailure(Self.describe(error))
        } catch {
            await handleFailure(Self.describe(error))
        }
    }

    /// 失败处理：记录错误、按决策重建连接池 / 重试 / 进入错误状态
    func handleFailure(_ message: String) async {
        lastError = message
        let decision = tracker.recordFailure()

        if decision.shouldResetSession {
            // 丢弃可能已失效的连接池（代理重载、节点切换、网络切换等场景）
            await api.resetSession()
        }

        if decision.shouldRetry {
            // 单次失败，5 秒后重试一次
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let cm = credentialManager,
                  let cookie = cm.cookie, !cookie.isEmpty,
                  let secToken = cm.secToken, !secToken.isEmpty else { return }
            do {
                let data = try await api.fetchAll(cookie: cookie, secToken: secToken)
                applySuccess(data)
                await NotificationHelper.shared.checkAndNotify(usage: data.usage)
                return
            } catch {
                lastError = Self.describe(error)
                let second = tracker.recordFailure()
                if second.isError {
                    state = .error
                }
                return
            }
        }

        if decision.isError {
            state = .error
        }
    }

    /// 拉取用量趋势。趋势是辅助信息：失败时静默保留旧数据，
    /// 绝不记录失败 / 不触发会话重建 / 不进入错误状态，避免拖垮主额度监控。
    private func fetchTrendIfNeeded(cookie: String, secToken: String, force: Bool) async {
        if !force,
           let fetchedAt = trendFetchedAt,
           Date().timeIntervalSince(fetchedAt) < trendCacheTTL {
            return
        }
        do {
            let t = try await api.fetchUsageTrend(cookie: cookie, secToken: secToken)
            trend = t
            trendError = nil
            trendFetchedAt = Date()
        } catch {
            // 保留 trend 旧值；记录原因供 UI 展示。
            // 不进 FailureTracker / 不触发会话重建，避免拖垮主额度监控。
            trendError = Self.describe(error)
        }
    }

    private func applySuccess(_ data: PlanData) {
        planData = data
        lastUpdated = Date()
        lastError = nil
        tracker.recordSuccess()
    }

    /// 错误描述：APIError 用中文用户文案，其余保留系统原始信息（英文，便于排查）
    static func describe(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? "Unknown error"
        }
        return error.localizedDescription
    }
}

// MARK: - 辅助

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
