import XCTest
@testable import SpacestratorKit

final class ChromeProfileTests: XCTestCase {

    /// Builds a temp Chrome base dir containing the bundled Local State fixture.
    private func makeChromeBase() throws -> String {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("chrome-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let fixture = try XCTUnwrap(
            Bundle.module.url(forResource: "ChromeLocalState", withExtension: "json",
                              subdirectory: "Fixtures")
                ?? Bundle.module.url(forResource: "ChromeLocalState", withExtension: "json")
        )
        let dest = tmp.appendingPathComponent("Local State")
        try FileManager.default.copyItem(at: fixture, to: dest)
        return tmp.path
    }

    func testNilReturnsDefault() {
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory(nil), "Default")
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory(""), "Default")
    }

    func testPassthroughLiterals() {
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory("Default"), "Default")
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory("Profile 2"), "Profile 2")
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory("System Profile"), "System Profile")
    }

    func testResolveByDisplayName() throws {
        let base = try makeChromeBase()
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory("work profile", chromeBase: base), "Profile 3")
    }

    func testResolveCaseInsensitive() throws {
        let base = try makeChromeBase()
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory("WORK PROFILE", chromeBase: base), "Profile 3")
    }

    func testResolveByGaiaName() throws {
        let base = try makeChromeBase()
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory("Alice Work", chromeBase: base), "Profile 3")
    }

    func testResolveByUserName() throws {
        let base = try makeChromeBase()
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory("side@example.com", chromeBase: base), "Profile 7")
    }

    func testResolveByDirectoryKey() throws {
        let base = try makeChromeBase()
        // The cache key itself ("Profile 7") should match case-insensitively too.
        XCTAssertEqual(ChromeProfile.resolveProfileDirectory("profile 7", chromeBase: base), "Profile 7")
    }

    func testUnknownProfileReturnsNil() throws {
        let base = try makeChromeBase()
        XCTAssertNil(ChromeProfile.resolveProfileDirectory("does-not-exist", chromeBase: base))
    }

    func testMissingLocalStateReturnsNil() {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-chrome-\(UUID().uuidString)").path
        XCTAssertNil(ChromeProfile.resolveProfileDirectory("work profile", chromeBase: base))
    }
}
