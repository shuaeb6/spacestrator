import Foundation

/// Owns the on-disk config location and JSON loading.
/// Ports the config-directory / list / load portions of engine/workspace.lua.
enum WorkspaceStore {

    /// Resolution order (first match wins):
    ///   1. $SPACESTRATOR_HOME
    ///   2. $WORKSPACE_HOME              (back-compat with the Hammerspoon setup)
    ///   3. ~/.spacestrator             (new default, if it already exists)
    ///   4. ~/.workspace                (legacy dir, if it already exists)
    ///   5. ~/.spacestrator             (created on demand)
    static func workspaceRoot() -> String {
        let env = ProcessInfo.processInfo.environment
        if let v = env["SPACESTRATOR_HOME"], !v.isEmpty { return v }
        if let v = env["WORKSPACE_HOME"], !v.isEmpty { return v }

        let home = NSHomeDirectory() as NSString
        let new = home.appendingPathComponent(".spacestrator")
        let legacy = home.appendingPathComponent(".workspace")
        let fm = FileManager.default
        if fm.fileExists(atPath: new) { return new }
        if fm.fileExists(atPath: legacy) { return legacy }
        return new
    }

    static func configDir() -> String {
        (workspaceRoot() as NSString).appendingPathComponent("configs")
    }

    /// Config basenames (without .json), sorted. Empty if the directory is missing.
    static func listProjectSlugs() -> [String] {
        let dir = configDir()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
            return []
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        return contents
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
            .sorted()
    }

    static func loadProjectConfig(_ slug: String) -> ProjectConfig? {
        let path = (configDir() as NSString).appendingPathComponent("\(slug).json")
        guard let data = FileManager.default.contents(atPath: path) else {
            Notify.send(title: "Spacestrator", body: "Missing config: \(path)")
            return nil
        }
        do {
            return try JSONDecoder().decode(ProjectConfig.self, from: data)
        } catch {
            Notify.send(title: "Spacestrator", body: "Invalid JSON: \(path)")
            return nil
        }
    }

    /// Ensure ~/.spacestrator/configs exists; returns the path.
    @discardableResult
    static func ensureConfigDir() -> String {
        let dir = configDir()
        try? FileManager.default.createDirectory(atPath: dir,
                                                 withIntermediateDirectories: true)
        return dir
    }

    /// Create a starter project JSON (without clobbering existing files) and return its path.
    static func createTemplateProject() -> String {
        ensureConfigDir()
        let base = "new-project"
        var slug = base
        var n = 1
        while FileManager.default.fileExists(
            atPath: (configDir() as NSString).appendingPathComponent("\(slug).json")) {
            n += 1
            slug = "\(base)-\(n)"
        }
        let path = (configDir() as NSString).appendingPathComponent("\(slug).json")
        try? Self.template.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    /// Self-explanatory starter config (valid JSON — no comments allowed).
    static let template = """
    {
      "name": "New Project",
      "space": "new",
      "apps": [
        { "type": "app",    "name": "Cursor",        "path": "/absolute/path/to/your/project" },
        { "type": "folder", "name": "Finder",        "path": "/absolute/path/to/your/project" },
        { "type": "chrome", "name": "Google Chrome", "profile": "Default" }
      ]
    }
    """

}
