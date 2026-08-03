import SwiftUI
import AppKit
import Combine

/// 菜单栏控制器：NSStatusItem + NSHostingView（响应式可靠方案）
@MainActor
final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()

    private let polling = PollingService.shared
    private let credentials = CredentialManager.shared
    private let settings = AppSettings.shared

    // MARK: - 启动

    func setup() {
        // 状态栏项：显式宽度，确保胶囊完整显示
        statusItem = NSStatusBar.system.statusItem(withLength: 120)
        guard let button = statusItem.button else { return }

        // NSHostingView 承载菜单栏标签（标准 SwiftUI 渲染，@Published 变化自动更新）
        let label = MenuBarLabel()
            .environmentObject(polling)
            .environmentObject(credentials)
            .environmentObject(settings)

        let hosting = NSHostingView(rootView: label)
        hosting.frame = NSRect(x: 0, y: 0, width: 120, height: 22)
        button.addSubview(hosting)
        button.setFrameSize(NSSize(width: 120, height: 22))

        // 点击切换弹出面板
        button.action = #selector(togglePopover)
        button.target = self
        button.sendAction(on: [.leftMouseUp])

        // 弹出面板
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(polling)
                .environmentObject(credentials)
                .environmentObject(settings)
        )
    }

    // MARK: - 弹出面板

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
