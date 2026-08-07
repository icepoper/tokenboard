import SwiftUI
import AppKit

/// 服务商切换：官方 logo 图标按钮，点击直接切换活动服务商
struct ProviderSwitcher: View {
    @EnvironmentObject var providers: ProviderManager

    var body: some View {
        HStack(spacing: 10) {
            ForEach(providers.registeredProviderIDs) { pid in
                providerButton(pid)
            }
        }
    }

    private func providerButton(_ pid: ProviderID) -> some View {
        let isActive = providers.activeProviderID == pid
        return Button {
            providers.switchTo(pid)
        } label: {
            Image(nsImage: Self.logo(for: pid))
                .resizable()
                .frame(width: 20, height: 20)
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(pid.displayName)
    }

    /// 官方 logo（退化为 SF Symbol）
    static func logo(for pid: ProviderID) -> NSImage {
        switch pid {
        case .qianwen:
            return NSImage(named: "qwen-logo")
                ?? NSImage(systemSymbolName: "text.bubble.fill", accessibilityDescription: nil)!
        case .deepseek:
            return NSImage(named: "deepseek-logo")
                ?? NSImage(systemSymbolName: "drop.fill", accessibilityDescription: nil)!
        }
    }
}
