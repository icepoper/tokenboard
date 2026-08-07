import XCTest
@testable import TokenBoard

/// 测试用 Mock 服务商：记录调用，不发起真实网络请求
@MainActor
final class MockProvider: Provider, ObservableObject {
    let id: ProviderID
    let displayName: String
    var credentialStatus: CredentialStatus
    var snapshot: ProviderSnapshot?
    var state: PollingState = .idle
    var isFailing = false
    var lastError: String?
    var lastUpdated: Date?
    var pollingInterval: Int = 60

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var refreshCount = 0

    init(id: ProviderID, credentialStatus: CredentialStatus = .incomplete) {
        self.id = id
        self.displayName = id.displayName
        self.credentialStatus = credentialStatus
    }

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func refresh() async { refreshCount += 1 }
    func restartIfNeeded() {}
}

/// ProviderManager：服务商注册 / 切换 / 持久化 / 凭证隔离
@MainActor
final class ProviderManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ProviderManager.activeProviderKey)
    }

    /// 默认活动服务商为千问，且千问已注册
    func testDefaultActiveProviderIsQianwen() {
        let manager = ProviderManager()
        XCTAssertEqual(manager.activeProviderID, .qianwen)
        XCTAssertEqual(manager.registeredProviders.map(\.id), [.qianwen, .deepseek])
    }

    /// 注册 DeepSeek 后切换：活动服务商更新、凭证完整立即启动、选择持久化
    func testRegisterAndSwitchToProvider() {
        let manager = ProviderManager()
        let mock = MockProvider(id: .deepseek, credentialStatus: .complete)
        manager.register(mock)

        XCTAssertEqual(manager.registeredProviders.map(\.id), [.qianwen, .deepseek])

        manager.switchTo(.deepseek)
        XCTAssertEqual(manager.activeProviderID, .deepseek)
        XCTAssertEqual(manager.activeProvider.id, .deepseek)
        XCTAssertEqual(mock.startCount, 1, "切换后凭证完整应立即启动轮询")
        XCTAssertEqual(mock.stopCount, 0)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: ProviderManager.activeProviderKey),
            "deepseek",
            "活动服务商选择应持久化"
        )
    }

    /// 切换到的服务商凭证不完整时：停止而非启动
    func testSwitchToIncompleteProviderStops() {
        let manager = ProviderManager()
        let mock = MockProvider(id: .deepseek, credentialStatus: .incomplete)
        manager.register(mock)

        manager.switchTo(.deepseek)
        XCTAssertEqual(manager.activeProviderID, .deepseek)
        XCTAssertEqual(mock.startCount, 0)
        XCTAssertEqual(mock.stopCount, 1)
    }

    /// 凭证状态按服务商隔离，互不影响
    func testCredentialIsolation() {
        let manager = ProviderManager()
        let mock = MockProvider(id: .deepseek, credentialStatus: .expired)
        manager.register(mock)

        XCTAssertEqual(mock.credentialStatus, .expired)
        manager.switchTo(.deepseek)
        XCTAssertEqual(manager.activeProvider.credentialStatus, .expired)
        // 千问仍为已注册服务商，其状态不受 DeepSeek 影响
        XCTAssertEqual(manager.registeredProviders.first?.id, .qianwen)
    }

    /// 重复切换到同一服务商应无副作用（不重复启动）
    func testSwitchToSameProviderNoOp() {
        let manager = ProviderManager()
        let mock = MockProvider(id: .deepseek, credentialStatus: .complete)
        manager.register(mock)

        manager.switchTo(.deepseek)
        manager.switchTo(.deepseek)
        XCTAssertEqual(mock.startCount, 1, "重复切换同一服务商不应重复启动")
    }
}
