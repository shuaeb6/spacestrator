import Foundation
import AppKit

/// Launch, focus, and path-open applications. Ports services/appManager.lua.
/// Uses /usr/bin/open for launching (faithful to the original, including -n / -a / -b
/// and Chrome's --profile-directory) and NSRunningApplication for focus/unhide.
enum AppManager {

    /// When NSRunningApplication lookup by name fails, resolve by bundle id
    /// (common with JetBrains/Cursor). Sourced from the shared AppCatalog.
    static let bundleHints: [String: String] = AppCatalog.bundleHints

    // MARK: - Resolution

    static func resolveApplication(name: String?, bundleId: String?) -> NSRunningApplication? {
        guard let name else { return nil }
        let running = NSWorkspace.shared.runningApplications

        if let bundleId, !bundleId.isEmpty {
            if let app = running.first(where: { $0.bundleIdentifier == bundleId }) { return app }
        }
        if let app = running.first(where: { $0.localizedName == name }) { return app }
        if let hint = bundleHints[name],
           let app = running.first(where: { $0.bundleIdentifier == hint }) {
            return app
        }
        return nil
    }

    static func isRunning(name: String?, bundleId: String?) -> Bool {
        resolveApplication(name: name, bundleId: bundleId) != nil
    }

    private static func focus(_ app: NSRunningApplication) {
        app.unhide()
        app.activate(options: [.activateAllWindows])
    }

    // MARK: - Launch / focus

    static func launchOrFocus(name: String, bundleId: String?) {
        if let app = resolveApplication(name: name, bundleId: bundleId) {
            focus(app)
            return
        }
        Shell.open(["-a", name])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if let app = resolveApplication(name: name, bundleId: bundleId) { focus(app) }
        }
    }

    // MARK: - Open at path (IDE opening a project folder)

    static func openApplicationAtPath(name: String, path: String, bundleId: String?, options: AppConfig) {
        guard !path.isEmpty, isDirectory(path) else {
            Notify.send(title: "Spacestrator",
                        body: "Path is not a folder (or missing): \(path) — \(name)")
            return
        }

        let newWindow = options.newWindow == true
        var args = newWindow ? ["-n"] : []
        args += ["-a", name, path]

        var success = Shell.open(args)
        let bundle = bundleId ?? bundleHints[name]
        if !success, let bundle {
            var fallback = newWindow ? ["-n"] : []
            fallback += ["-b", bundle, path]
            success = Shell.open(fallback)
        }
        if !success {
            Notify.send(title: "Spacestrator",
                        body: "open failed for \(name) — check install name or set bundleId in JSON")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let app = resolveApplication(name: name, bundleId: bundleId) {
                focus(app)
            } else {
                Shell.open(["-a", name])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if let a = resolveApplication(name: name, bundleId: bundleId) { focus(a) }
                }
            }
        }

        // Decide dialog action. Explicit newWindow wins; otherwise apps the
        // catalog flags as showing an "Open Project" dialog default to dismissing it.
        var dialog = options.openProjectDialog
        if newWindow {
            dialog = .newWindow
        } else if dialog == nil, AppCatalog.entry(forName: name)?.opensProjectDialog == true {
            dialog = .newWindow
        }
        if let dialog, dialog != .off {
            JetBrainsOpenProject.schedule(processName: name,
                                          choice: dialog,
                                          customButtonLabel: options.openProjectDialogButton)
        }
    }

    // MARK: - Chrome with a specific profile

    static func openChromeWithProfile(profile: String?, profileDirectory: String?) {
        var dir = profileDirectory?.trimmingCharacters(in: .whitespaces)
        if dir == nil || dir!.isEmpty {
            dir = ChromeProfile.resolveProfileDirectory(profile)
        }
        guard let resolved = dir, !resolved.isEmpty else {
            Notify.send(title: "Spacestrator",
                        body: "Unknown Chrome profile \"\(profile ?? "")\". Add profileDirectory "
                            + "(e.g. \"Profile 3\") from chrome://version → Profile Path.")
            return
        }
        // No -n: a new window tends to open on the current Space.
        let ok = Shell.open(["-a", "Google Chrome", "--args", "--profile-directory=\(resolved)"])
        if !ok {
            Notify.send(title: "Spacestrator",
                        body: "Chrome failed to open with profile directory: \(resolved)")
        }
    }

    // MARK: - Folder in Finder

    static func openFolder(_ path: String?) {
        guard let path, !path.isEmpty else { return }
        guard isDirectory(path) else {
            Notify.send(title: "Spacestrator", body: "Folder not found (or not a directory): \(path)")
            return
        }
        Shell.open(["-a", "Finder", path])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let finder = resolveApplication(name: "Finder", bundleId: nil) { focus(finder) }
        }
    }

    // MARK: - iOS Simulator

    static func openSimulator(device: String?) {
        Shell.open(["-a", "Simulator"])
        guard let device, !device.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Shell.run("/usr/bin/xcrun", ["simctl", "boot", device])
        }
    }

    // MARK: - Helpers

    private static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}
