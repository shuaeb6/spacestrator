import Foundation

/// Orchestrates loading a project: optionally switch/create a space, then launch
/// each configured app on a short stagger. Direct port of engine/workspace.lua
/// loadProject.
///
/// Keeping every window on the target desktop relies on the macOS "switch to a
/// Space with open windows" behavior being OFF (see `SpaceSwitchPrefs`); with it
/// on, macOS drags focus back to an app's existing Space mid-launch. On current
/// macOS there is no SIP-free private API to move windows across Spaces, so that
/// setting is the supported mechanism and Spacestrator manages it for the user.
enum WorkspaceLoader {

    static func loadProject(_ slug: String) {
        guard let project = WorkspaceStore.loadProjectConfig(slug) else { return }
        let apps = project.apps
        let displayName = project.name ?? slug

        let scheduleApps = {
            for (i, app) in apps.enumerated() {
                let delay = 0.25 * Double(i)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    handle(app)
                }
            }
            let tail = 0.25 * Double(max(0, apps.count - 1)) + 0.75
            DispatchQueue.main.asyncAfter(deadline: .now() + tail) {
                Notify.send(title: "Spacestrator", body: "Loaded: \(displayName)")
            }
        }

        if SpaceManager.shared.spaceSpecIsNew(project.space) {
            SpaceManager.shared.gotoNewUserSpace { _ in scheduleApps() }
        } else if case .index = project.space {
            SpaceManager.shared.gotoSpace(project.space)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: scheduleApps)
        } else {
            scheduleApps()
        }
    }

    private static func handle(_ app: AppConfig) {
        switch app.type {
        case .app:
            handleApp(app)
        case .chrome:
            AppManager.openChromeWithProfile(profile: app.profile, profileDirectory: app.profileDirectory)
        case .folder:
            AppManager.openFolder(app.path)
        case .simulator:
            AppManager.openSimulator(device: app.device)
        }
    }

    private static func handleApp(_ app: AppConfig) {
        guard let name = app.name else { return }
        if let path = app.path, !path.isEmpty {
            AppManager.openApplicationAtPath(name: name, path: path, bundleId: app.bundleId, options: app)
        } else {
            AppManager.launchOrFocus(name: name, bundleId: app.bundleId)
        }
    }
}
