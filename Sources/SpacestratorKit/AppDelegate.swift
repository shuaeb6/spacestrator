import Foundation
import AppKit
import Carbon.HIToolbox

/// App startup wiring. Equivalent of init.lua:
///   menuBarApp.start(); workspaceSnapshot.bindHotkey()
/// plus first-run permission prompts.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        Notify.bootstrap()

        // Accessibility is required for the IDE dialog automation; prompt on first run.
        if !Permissions.ensureAccessibility(prompt: true) {
            Log.info("Accessibility not yet granted — grant it in System Settings, then relaunch.")
        }

        menuBar.start()
        bindSnapshotHotkey()

        // Keep project windows on the desktop we launch them onto. Without this,
        // macOS's default "switch to a Space with open windows for the application"
        // drags focus back to an app's existing Space mid-launch, scattering the
        // project across desktops. Applied once (guarded), then it sticks.
        if !SpaceSwitchPrefs.isDisabled {
            if SpaceSwitchPrefs.disable() {
                Log.info("Configured macOS so app activation won't jump Spaces (Dock restarted).")
                Notify.send(title: "Spacestrator",
                            body: "Set up desktop switching so project windows stay on their desktop.")
            }
        }

        // Bring the app forward so first-run permission prompts appear in front and
        // the status item registers immediately.
        NSApp.activate(ignoringOtherApps: true)

        Log.info("Spacestrator ready. Configs: \(WorkspaceStore.configDir())")
    }

    /// ⌘⌥⌃S → snapshot per-space windows to the console.
    private func bindSnapshotHotkey() {
        HotKeyCenter.shared.bind(keyCode: UInt32(kVK_ANSI_S),
                                 modifiers: UInt32(cmdKey | optionKey | controlKey)) {
            WorkspaceSnapshot.snapshotWorkspaces()
        }
    }

    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
