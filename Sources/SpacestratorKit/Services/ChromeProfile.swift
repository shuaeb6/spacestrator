import Foundation

/// Resolves a Chrome profile display name (e.g. "zdrawi profile") to its real
/// user-data subdirectory (e.g. "Profile 3") by reading Chrome's `Local State`.
/// Direct port of services/chromeProfile.lua.
enum ChromeProfile {

    static func resolveProfileDirectory(_ configValue: String?, chromeBase: String? = nil) -> String? {
        guard let raw = configValue, !raw.isEmpty else { return "Default" }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if trimmed == "Default" || trimmed == "System Profile" { return trimmed }
        if trimmed.range(of: #"^Profile \d+$"#, options: .regularExpression) != nil { return trimmed }

        let base = chromeBase ?? (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Application Support/Google/Chrome")
        let statePath = (base as NSString).appendingPathComponent("Local State")

        guard let data = FileManager.default.contents(atPath: statePath),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: Any] else {
            return nil
        }

        let want = trimmed.lowercased()
        for (dir, value) in cache {
            if dir.lowercased() == want { return dir }
            guard let meta = value as? [String: Any] else { continue }
            for key in ["name", "gaia_name", "user_name"] {
                if let n = meta[key] as? String, n.lowercased() == want {
                    return dir
                }
            }
        }
        return nil
    }
}
