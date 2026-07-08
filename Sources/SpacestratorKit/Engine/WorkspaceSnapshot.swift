import Foundation
import CoreGraphics
import CSkyLight

/// Enumerates windows per Mission Control space on the active display and emits
/// pretty JSON: [{ "space": i, "windows": [{ "app", "title" }] }].
/// Ports engine/workspaceSnapshot.lua. Window→space mapping uses private SkyLight;
/// window titles require Screen Recording permission.
enum WorkspaceSnapshot {

    struct WindowEntry: Encodable { let app: String; let title: String }
    struct SpaceEntry: Encodable { let space: Int; let windows: [WindowEntry] }

    private static func collect() -> [SpaceEntry]? {
        guard let displays = wo_copy_managed_display_spaces()?.takeRetainedValue() as? [[String: Any]] else {
            Log.error("[snapshot] SLSCopyManagedDisplaySpaces unavailable")
            return nil
        }
        let activeDisplay = wo_active_display_identifier()?.takeRetainedValue() as String?
        let chosen = displays.first(where: { ($0["Display Identifier"] as? String) == activeDisplay })
            ?? displays.first
        guard let spaces = chosen?["Spaces"] as? [[String: Any]] else {
            Log.error("[snapshot] no spaces for display")
            return nil
        }

        // On-screen windows (owner + title). Title needs Screen Recording.
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Build CGWindowID -> (app, title).
        var meta: [UInt64: (String, String)] = [:]
        var windowIDs: [UInt64] = []
        for info in infoList {
            guard let wid = (info[kCGWindowNumber as String] as? NSNumber)?.uint64Value else { continue }
            let app = (info[kCGWindowOwnerName as String] as? String) ?? "Unknown"
            let title = (info[kCGWindowName as String] as? String) ?? ""
            meta[wid] = (app, title)
            windowIDs.append(wid)
        }

        // Map each window to its space ids. SLSCopySpacesForWindows returns the
        // spaces containing ANY window in the passed set, so to get a per-window
        // mapping (like hs.spaces.windowSpaces) we query one window at a time.
        var windowSpaces: [UInt64: Set<UInt64>] = [:]
        for wid in windowIDs {
            let one = [NSNumber(value: wid)] as CFArray
            guard let spaceList = wo_copy_spaces_for_windows(one, 0x7 /* all spaces */)?
                .takeRetainedValue() as? [NSNumber] else { continue }
            windowSpaces[wid] = Set(spaceList.map { $0.uint64Value })
        }

        var result: [SpaceEntry] = []
        for (i, space) in spaces.enumerated() {
            let sid: UInt64 = {
                if let n = space["ManagedSpaceID"] as? NSNumber { return n.uint64Value }
                if let n = space["id64"] as? NSNumber { return n.uint64Value }
                return 0
            }()
            var windows: [WindowEntry] = []
            for wid in windowIDs {
                if windowSpaces[wid]?.contains(sid) == true, let (app, title) = meta[wid] {
                    windows.append(WindowEntry(app: app, title: title))
                }
            }
            result.append(SpaceEntry(space: i + 1, windows: windows))
        }
        return result
    }

    private static func encoded() -> String? {
        guard let result = collect() else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Print JSON to stdout (console), matching snapshotWorkspaces().
    static func snapshotWorkspaces() {
        guard let json = encoded() else { return }
        Log.raw(json)
    }

    /// Also write JSON to a file (default /tmp/workspace-snapshot.json).
    static func snapshotWorkspacesToFile(path: String = "/tmp/workspace-snapshot.json") {
        guard let json = encoded() else { return }
        Log.raw(json)
        do {
            try json.write(toFile: path, atomically: true, encoding: .utf8)
            Notify.send(title: "Spacestrator snapshot", body: "Wrote \(path)")
        } catch {
            Log.error("[snapshot] could not write: \(path)")
        }
    }
}
