import XCTest
@testable import SpacestratorKit

final class WorkspaceStoreTests: XCTestCase {

    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("workspace-test-\(UUID().uuidString)")
        let configs = home.appendingPathComponent("configs")
        try FileManager.default.createDirectory(at: configs, withIntermediateDirectories: true)
        setenv("SPACESTRATOR_HOME", home.path, 1)
    }

    override func tearDownWithError() throws {
        unsetenv("SPACESTRATOR_HOME")
        try? FileManager.default.removeItem(at: home)
    }

    private func write(_ name: String, _ contents: String) throws {
        let url = home.appendingPathComponent("configs/\(name)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    func testConfigDirHonorsEnvOverride() {
        XCTAssertEqual(WorkspaceStore.configDir(), home.appendingPathComponent("configs").path)
    }

    func testListProjectSlugsSortedAndFiltered() throws {
        try write("zeta.json", "{}")
        try write("alpha.json", "{}")
        try write("notes.txt", "ignore me")
        XCTAssertEqual(WorkspaceStore.listProjectSlugs(), ["alpha", "zeta"])
    }

    func testListEmptyWhenNoConfigs() {
        XCTAssertEqual(WorkspaceStore.listProjectSlugs(), [])
    }

    func testLoadValidConfig() throws {
        try write("demo.json", #"{ "name": "Demo", "space": 2, "apps": [ { "name": "Cursor" } ] }"#)
        let cfg = WorkspaceStore.loadProjectConfig("demo")
        XCTAssertEqual(cfg?.name, "Demo")
        XCTAssertEqual(cfg?.space, .index(2))
        XCTAssertEqual(cfg?.apps.count, 1)
    }

    func testLoadMissingConfigReturnsNil() {
        XCTAssertNil(WorkspaceStore.loadProjectConfig("nope"))
    }

    func testLoadInvalidJSONReturnsNil() throws {
        try write("broken.json", "{ not json ]")
        XCTAssertNil(WorkspaceStore.loadProjectConfig("broken"))
    }
}
