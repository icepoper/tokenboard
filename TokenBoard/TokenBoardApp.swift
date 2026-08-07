import SwiftUI
import AppKit

// MARK: - AppDelegate（管理 NSStatusItem 菜单栏）

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 纯菜单栏应用，不在 Dock 显示
        NSApp.setActivationPolicy(.accessory)

        // 初始化菜单栏
        let controller = StatusItemController()
        controller.setup()
        statusItemController = controller

        // 请求通知权限
        Task {
            await NotificationHelper.shared.requestPermission()
        }

        // 凭证完整则立即启动活动服务商轮询
        let providers = ProviderManager.shared
        let active = providers.activeProvider
        if active.credentialStatus == .complete {
            active.start()
        }
    }
}

// MARK: - App 入口

struct TokenBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var providers = ProviderManager.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        // 独立设置窗口（macOS 13+ 官方 WindowGroup 方案）
        WindowGroup("设置", id: "settings") {
            SettingsView()
                .environmentObject(providers)
                .environmentObject(settings)
        }
        .windowResizability(.contentSize)
    }
}
