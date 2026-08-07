import Foundation
import Combine

/// 千问服务商：包装 PollingService 与 QianwenCredentialStore，
/// 对外暴露 Provider 协议接口。
@MainActor
final class QianwenProvider: Provider, ObservableObject {
    static let shared = QianwenProvider()

    let id: ProviderID = .qianwen
    let displayName = "千问"

    private let polling: PollingService
    private let credentials: QianwenCredentialStore
    private var cancellables = Set<AnyCancellable>()

    init(polling: PollingService? = nil, credentials: QianwenCredentialStore? = nil) {
        let polling = polling ?? .shared
        let credentials = credentials ?? .shared
        self.polling = polling
        self.credentials = credentials
        polling.credentialManager = credentials
        // 转发内部变化到自身 objectWillChange，保证 UI 观察 ProviderManager 能收到更新
        polling.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        credentials.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var credentialStatus: CredentialStatus { credentials.status }

    var snapshot: ProviderSnapshot? {
        guard let planData = polling.planData else { return nil }
        return .qianwen(QianwenSnapshot(
            planData: planData,
            trend: polling.trend,
            trendError: polling.trendError
        ))
    }

    var state: PollingState { polling.state }
    var isFailing: Bool { polling.isFailing }
    var lastError: String? { polling.lastError }
    var lastUpdated: Date? { polling.lastUpdated }

    var pollingInterval: Int {
        get { polling.pollingInterval }
        set { polling.pollingInterval = newValue }
    }

    func start() { polling.start() }
    func stop() { polling.stop() }
    func refresh() async { await polling.refresh() }
    func restartIfNeeded() { polling.restartIfNeeded() }

    // MARK: - 千问凭证操作（设置页使用）

    func saveCredential(cookie: String, secToken: String) {
        credentials.save(cookie: cookie, secToken: secToken)
    }

    func clearCredential() {
        credentials.clear()
    }
}
