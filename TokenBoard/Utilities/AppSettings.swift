import SwiftUI
import AppKit


/// 应用内语言选项（跟随系统 / 中文 / English）
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case en = "en"

    var id: String { rawValue }

    /// 对应的 AppleLanguages 语言码；nil 表示跟随系统
    var appleLanguagesCode: String? {
        switch self {
        case .system: return nil
        case .zhHans: return "zh-Hans"
        case .en: return "en"
        }
    }

    /// 语言显示名（语言自名不翻译；"跟随系统" 本地化）
    var displayName: String {
        switch self {
        case .system: return String(localized: "跟随系统")
        case .zhHans: return "中文"
        case .en: return "English"
        }
    }
}

/// 应用设置（响应式单一数据源，设置变更自动通知所有观察者）
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - 键名

    static let capsuleBgKey = "capsuleBackgroundColor"
    static let pollingIntervalKey = "pollingInterval"
    static let languageKey = "appLanguage"

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

    /// 界面语言（跟随系统 / 中文 / English），持久化到 UserDefaults
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey) }
    }

    /// 背景是否为深色（决定文字颜色）
    @Published private(set) var isCapsuleBackgroundDark: Bool

    // MARK: - 初始化

    private init() {
        let color = Self.loadCapsuleColor() ?? Color(nsColor: Self.defaultCapsuleBackground)
        capsuleBackgroundColor = color
        isCapsuleBackgroundDark = Self.computeDarkness(color)
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: Self.languageKey) ?? "") ?? .system
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
