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
        // 状态栏项：宽度按最宽内容（QW 100%）测量，避免过宽留白
        let width = Self.idealItemWidth()
        statusItem = NSStatusBar.system.statusItem(withLength: width)
        guard let button = statusItem.button else { return }

        // NSHostingView 承载菜单栏标签（标准 SwiftUI 渲染，@Published 变化自动更新）
        let label = MenuBarLabel()
            .environmentObject(polling)
            .environmentObject(credentials)
            .environmentObject(settings)

        let hosting = NSHostingView(rootView: label)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 22)
        button.addSubview(hosting)
        button.setFrameSize(NSSize(width: width, height: 22))

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

    /// 用最宽可能内容（"QW 100% | 100%"）测量状态项宽度，数值变化时宽度不跳动
    private static func idealItemWidth() -> CGFloat {
        let probe = NSHostingView(rootView: ProgressRing(progress: 1, text: "100% | 100%"))
        return ceil(probe.fittingSize.width)
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
