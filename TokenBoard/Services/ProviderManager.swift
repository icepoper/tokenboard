import Foundation
import Combine

/// 服务商管理器：注册全部服务商、维护活动服务商、转发变化到 UI
@MainActor
final class ProviderManager: ObservableObject {
    /// 全局单例
    static let shared = ProviderManager()

    /// 活动服务商持久化键
    static let activeProviderKey = "activeProvider"

    /// 活动服务商标识（切换时持久化）
    @Published private(set) var activeProviderID: ProviderID {
        didSet {
            UserDefaults.standard.set(activeProviderID.rawValue, forKey: Self.activeProviderKey)
        }
    }

    private var providers: [ProviderID: any Provider] = [:]
    private var cancellables = Set<AnyCancellable>()

    /// 活动服务商
    var activeProvider: any Provider {
        providers[activeProviderID] ?? providers[.qianwen]!
    }

    /// 已注册服务商列表（按 ProviderID 顺序）
    var registeredProviders: [any Provider] {
        ProviderID.allCases.compactMap { providers[$0] }
    }

    /// 已注册服务商标识列表（供 UI 迭代）
    var registeredProviderIDs: [ProviderID] {
        ProviderID.allCases.filter { providers[$0] != nil }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.activeProviderKey)
        activeProviderID = ProviderID(rawValue: saved ?? "") ?? .qianwen
        register(QianwenProvider.shared)
        register(DeepSeekProvider.shared)
    }

    /// 注册服务商并转发其变化到自身
    func register(_ provider: any Provider) {
        providers[provider.id] = provider
        provider.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// 切换活动服务商；切换后若凭证完整立即拉取一次
    func switchTo(_ id: ProviderID) {
        guard providers[id] != nil, id != activeProviderID else { return }
        activeProviderID = id
        let provider = activeProvider
        if provider.credentialStatus == .complete {
            provider.start()
        } else {
            provider.stop()
        }
    }
}
