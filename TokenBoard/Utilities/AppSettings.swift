import SwiftUI
import AppKit

/// 应用设置（响应式单一数据源，设置变更自动通知所有观察者）
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - 键名

    static let capsuleBgKey = "capsuleBackgroundColor"
    static let pollingIntervalKey = "pollingInterval"

    /// 默认胶囊背景色（深墨蓝，菜单栏上显眼）
    static let defaultCapsuleBackground = NSColor(
        calibratedRed: 0.09, green: 0.13, blue: 0.19, alpha: 1.0
    )

    // MARK: - 发布状态

    /// 胶囊背景色（任何观察者自动刷新）
    @Published var capsuleBackgroundColor: Color {
        didSet {
            persistCapsuleColor()
        }
    }

    /// 背景是否为深色（决定文字颜色）
    @Published private(set) var isCapsuleBackgroundDark: Bool

    // MARK: - 初始化

    private init() {
        let color = Self.loadCapsuleColor() ?? Color(nsColor: Self.defaultCapsuleBackground)
        capsuleBackgroundColor = color
        isCapsuleBackgroundDark = Self.computeDarkness(color)
    }

    // MARK: - 操作

    /// 恢复默认胶囊背景色
    func resetCapsuleColor() {
        capsuleBackgroundColor = Color(nsColor: Self.defaultCapsuleBackground)
    }

    // MARK: - 持久化

    private func persistCapsuleColor() {
        let ns = NSColor(capsuleBackgroundColor).usingColorSpace(.sRGB)
            ?? NSColor(capsuleBackgroundColor)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: ns, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: Self.capsuleBgKey)
        }
        isCapsuleBackgroundDark = Self.computeDarkness(Color(nsColor: ns))
    }

    private static func loadCapsuleColor() -> Color? {
        guard let data = UserDefaults.standard.data(forKey: capsuleBgKey),
              let ns = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSColor else {
            return nil
        }
        return Color(nsColor: ns)
    }

    private static func computeDarkness(_ color: Color) -> Bool {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? defaultCapsuleBackground
        let luminance = 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent
        return luminance < 0.5
    }
}
