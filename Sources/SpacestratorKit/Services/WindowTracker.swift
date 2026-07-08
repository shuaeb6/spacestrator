import Foundation
import AppKit

/// Optional focused-application logging, gated on WORKSPACE_TRACK_WINDOWS=1.
/// Ports services/windowTracker.lua. The Lua version logged focused *windows* via
/// hs.window.filter; AppKit exposes app-activation cleanly through NSWorkspace.
/// (Per-window title tracking would additionally require AX observers.)
enum WindowTracker {
    static func start() {
        guard ProcessInfo.processInfo.environment["WORKSPACE_TRACK_WINDOWS"] == "1" else { return }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Log.info("focused app: \(app?.localizedName ?? "Unknown")")
        }
        Log.info("Window tracking enabled (focused-app logging).")
    }
}
