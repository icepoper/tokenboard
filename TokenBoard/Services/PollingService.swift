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

    /// 轮询间隔（秒），持久化到 UserDefaults
    var pollingInterval: Int {
        get { UserDefaults.standard.integer(forKey: "pollingInterval").nonZero ?? 60 }
        set {
            UserDefaults.standard.set(newValue, forKey: "pollingInterval")
            restartIfNeeded()
        }
    }

    private let api = QianwenAPI()
    private var pollingTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    private let maxConsecutiveFailures = 3

    weak var credentialManager: CredentialManager?

    // MARK: - 生命周期

    /// 启动轮询
    func start() {
        guard credentialManager?.status == .complete else {
            state = .idle
            return
        }
        stop()
        state = .polling
        consecutiveFailures = 0

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
        await doFetch()
        if credentialManager?.status == .complete {
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
        }
    }

    // MARK: - 内部

    private func doFetch() async {
        guard let cm = credentialManager,
              let cookie = cm.cookie, !cookie.isEmpty,
              let secToken = cm.secToken, !secToken.isEmpty else {
            state = .idle
            return
        }

        do {
            let data = try await api.fetchAll(cookie: cookie, secToken: secToken)
            planData = data
            lastUpdated = Date()
            consecutiveFailures = 0

            // 额度预警
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
            await handleFailure()
        } catch {
            await handleFailure()
        }
    }

    private func handleFailure() async {
        consecutiveFailures += 1

        if consecutiveFailures == 1 {
            // 单次失败，5 秒后重试一次
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let cm = credentialManager,
                  let cookie = cm.cookie, !cookie.isEmpty,
                  let secToken = cm.secToken, !secToken.isEmpty else { return }
            do {
                let data = try await api.fetchAll(cookie: cookie, secToken: secToken)
                planData = data
                lastUpdated = Date()
                consecutiveFailures = 0
                return
            } catch {
                consecutiveFailures += 1
            }
        }

        if consecutiveFailures >= maxConsecutiveFailures {
            state = .error
        }
    }
}

// MARK: - 辅助

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
