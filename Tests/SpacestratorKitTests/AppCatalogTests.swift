import XCTest
@testable import SpacestratorKit

final class AppCatalogTests: XCTestCase {

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(AppCatalog.bundleId(forName: "cursor"), "com.todesktop.230313mzl4w4u92")
        XCTAssertEqual(AppCatalog.bundleId(forName: "CURSOR"), "com.todesktop.230313mzl4w4u92")
    }

    func testKnownEntries() {
        XCTAssertEqual(AppCatalog.bundleId(forName: "Visual Studio Code"), "com.microsoft.VSCode")
        XCTAssertEqual(AppCatalog.bundleId(forName: "Google Chrome"), "com.google.Chrome")
        XCTAssertNil(AppCatalog.bundleId(forName: "Totally Made Up App"))
    }

    func testSuggestedTypes() {
        XCTAssertEqual(AppCatalog.entry(forName: "Google Chrome")?.suggestedType, .chrome)
        XCTAssertEqual(AppCatalog.entry(forName: "Finder")?.suggestedType, .folder)
        XCTAssertEqual(AppCatalog.entry(forName: "Simulator")?.suggestedType, .simulator)
        XCTAssertEqual(AppCatalog.entry(forName: "Cursor")?.suggestedType, .app)
    }

    func testProjectDialogFlag() {
        XCTAssertTrue(AppCatalog.entry(forName: "Android Studio")?.opensProjectDialog ?? false)
        XCTAssertTrue(AppCatalog.entry(forName: "IntelliJ IDEA")?.opensProjectDialog ?? false)
        XCTAssertFalse(AppCatalog.entry(forName: "Visual Studio Code")?.opensProjectDialog ?? true)
    }

    func testBundleHintsCoverCatalog() {
        XCTAssertEqual(AppCatalog.bundleHints.count, AppCatalog.entries.count)
        XCTAssertEqual(AppCatalog.bundleHints["Slack"], "com.tinyspeck.slackmacgap")
    }

    func testCategoriesAreOrderedAndNonEmpty() {
        let cats = AppCatalog.byCategory
        XCTAssertEqual(cats.first?.0, "Browsers")
        XCTAssertTrue(cats.allSatisfy { !$0.1.isEmpty })
    }
}
