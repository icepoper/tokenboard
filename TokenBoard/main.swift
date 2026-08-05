import Foundation

// 应用内语言覆盖：必须在 NSApplicationMain 启动前写入 AppleLanguages，
// 否则 Bundle 的 preferredLocalizations 已按系统语言解析，覆盖不会生效。
// 键名与 AppSettings.languageKey 保持一致。
let rawLanguage = UserDefaults.standard.string(forKey: "appLanguage")
if let code = AppLanguage(rawValue: rawLanguage ?? "")?.appleLanguagesCode {
    UserDefaults.standard.set([code], forKey: "AppleLanguages")
} else {
    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
}

TokenBoardApp.main()
