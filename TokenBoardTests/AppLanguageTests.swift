import XCTest
@testable import TokenBoard

/// 应用内语言选项测试
final class AppLanguageTests: XCTestCase {

    func testAppleLanguagesCodeMapping() {
        XCTAssertNil(AppLanguage.system.appleLanguagesCode)
        XCTAssertEqual(AppLanguage.zhHans.appleLanguagesCode, "zh-Hans")
        XCTAssertEqual(AppLanguage.en.appleLanguagesCode, "en")
    }

    func testAllCasesOrder() {
        XCTAssertEqual(AppLanguage.allCases, [.system, .zhHans, .en])
    }

    /// 「剩余 XX%」数值场景：走既有 key "剩余 %lld%%"（中英文均正常翻译）
    func testRemainingPercentNumericLocalization() {
        let en = Bundle.main.url(forResource: "en", withExtension: "lproj").flatMap { Bundle(url: $0) }!
        let zh = Bundle.main.url(forResource: "zh-Hans", withExtension: "lproj").flatMap { Bundle(url: $0) }!
        XCTAssertEqual(
            String(localized: "剩余 \(Int(85))%", bundle: en, locale: Locale(identifier: "en")),
            "Remaining 85%"
        )
        XCTAssertEqual(
            String(localized: "剩余 \(Int(85))%", bundle: zh, locale: Locale(identifier: "zh-Hans")),
            "剩余 85%"
        )
    }

    /// 「剩余 --%」未知场景：v0.1.5 曾因 key 缺失在英文下回退中文，必须翻译
    func testRemainingPercentUnknownLocalization() {
        let en = Bundle.main.url(forResource: "en", withExtension: "lproj").flatMap { Bundle(url: $0) }!
        let zh = Bundle.main.url(forResource: "zh-Hans", withExtension: "lproj").flatMap { Bundle(url: $0) }!
        XCTAssertEqual(
            String(localized: "剩余 --%", bundle: en, locale: Locale(identifier: "en")),
            "Remaining --%"
        )
        XCTAssertEqual(
            String(localized: "剩余 --%", bundle: zh, locale: Locale(identifier: "zh-Hans")),
            "剩余 --%"
        )
    }
}