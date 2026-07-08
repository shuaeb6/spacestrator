import XCTest
@testable import SpacestratorKit

final class ConfigDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> ProjectConfig {
        try JSONDecoder().decode(ProjectConfig.self, from: Data(json.utf8))
    }

    // MARK: - SpaceSpec polymorphism

    func testSpaceNewString() throws {
        let p = try decode(#"{ "name": "P", "space": "new", "apps": [] }"#)
        XCTAssertEqual(p.space, .new)
        XCTAssertTrue(p.space.isNew)
    }

    func testSpaceNumericIndex() throws {
        let p = try decode(#"{ "space": 2, "apps": [] }"#)
        XCTAssertEqual(p.space, .index(2))
    }

    func testSpaceNumericString() throws {
        let p = try decode(#"{ "space": "3", "apps": [] }"#)
        XCTAssertEqual(p.space, .index(3))
    }

    func testSpaceMissingIsNone() throws {
        let p = try decode(#"{ "apps": [] }"#)
        XCTAssertEqual(p.space, .none)
        XCTAssertFalse(p.space.isNew)
    }

    func testSpaceGarbageStringIsNone() throws {
        let p = try decode(#"{ "space": "left", "apps": [] }"#)
        XCTAssertEqual(p.space, .none)
    }

    // MARK: - AppType + defaults

    func testAppTypeDefaultsToApp() throws {
        let p = try decode(#"{ "apps": [ { "name": "Cursor", "path": "/x" } ] }"#)
        XCTAssertEqual(p.apps.first?.type, .app)
    }

    func testAllAppTypesDecode() throws {
        let p = try decode("""
        { "apps": [
            { "type": "app", "name": "Cursor" },
            { "type": "chrome", "name": "Google Chrome", "profile": "work" },
            { "type": "folder", "name": "Finder", "path": "/x" },
            { "type": "simulator", "name": "Simulator", "device": "iPhone 15" }
        ] }
        """)
        XCTAssertEqual(p.apps.map(\.type), [.app, .chrome, .folder, .simulator])
        XCTAssertEqual(p.apps[1].profile, "work")
        XCTAssertEqual(p.apps[3].device, "iPhone 15")
    }

    // MARK: - DialogChoice leniency

    func testDialogChoiceBoolTrue() throws {
        let p = try decode(#"{ "apps": [ { "name": "AS", "openProjectDialog": true } ] }"#)
        XCTAssertEqual(p.apps.first?.openProjectDialog, .newWindow)
    }

    func testDialogChoiceBoolFalse() throws {
        let p = try decode(#"{ "apps": [ { "name": "AS", "openProjectDialog": false } ] }"#)
        XCTAssertEqual(p.apps.first?.openProjectDialog, .off)
    }

    func testDialogChoiceStrings() throws {
        let p = try decode("""
        { "apps": [
            { "name": "a", "openProjectDialog": "newWindow" },
            { "name": "b", "openProjectDialog": "thisWindow" },
            { "name": "c", "openProjectDialog": "none" }
        ] }
        """)
        XCTAssertEqual(p.apps.map(\.openProjectDialog), [.newWindow, .thisWindow, .off])
    }

    // MARK: - Full fixture (mirrors examples/projectX.json)

    func testFullProjectDecode() throws {
        let p = try decode("""
        {
          "name": "Project 1",
          "space": "new",
          "apps": [
            { "name": "Android Studio", "type": "app", "path": "/p", "newWindow": true },
            { "name": "Cursor", "type": "app", "path": "/p" },
            { "name": "Finder", "type": "folder", "path": "/p" },
            { "name": "Google Chrome", "type": "chrome", "profile": "work profile" }
          ]
        }
        """)
        XCTAssertEqual(p.name, "Project 1")
        XCTAssertEqual(p.space, .new)
        XCTAssertEqual(p.apps.count, 4)
        XCTAssertEqual(p.apps[0].newWindow, true)
        XCTAssertEqual(p.apps[3].profile, "work profile")
    }
}
