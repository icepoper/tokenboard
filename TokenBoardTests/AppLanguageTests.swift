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
}
