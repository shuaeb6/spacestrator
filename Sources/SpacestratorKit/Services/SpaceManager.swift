import Foundation

/// Public space API used by the loader. Ports the surface of spaceManager.lua
/// (gotoSpace / gotoNewUserSpace / spaceSpecIsNew) over a pluggable backend.
final class SpaceManager {
    static let shared = SpaceManager()

    let backend: SpaceBackend?

    private init() {
        // Prefer yabai (SIP-safe CLI); otherwise drive Mission Control through the
        // Dock's Accessibility API — the version-independent approach Hammerspoon
        // uses and the only one that reliably creates a *usable* desktop on current
        // macOS. The private SkyLight create path is kept only as a last resort.
        if let yabai = YabaiSpaceBackend() {
            backend = yabai
            Log.info("Space backend: yabai")
        } else if MissionControlSpaceBackend.isAvailable {
            backend = MissionControlSpaceBackend()
            Log.info("Space backend: Mission Control (Accessibility)")
        } else if SkyLightSpaceBackend.isAvailable {
            // AX not yet granted — offer the (fragile) SkyLight path meanwhile.
            backend = SkyLightSpaceBackend()
            Log.info("Space backend: SkyLight (private API) — grant Accessibility for the reliable path")
        } else {
            backend = nil
            Log.error("No space backend available — projects will load on the current space.")
        }
    }

    /// Name of the backend that would be used, detected without building the
    /// singleton or logging (for the CLI banner / --status).
    static var detectedBackendName: String {
        if Shell.which("yabai") != nil { return "yabai" }
        if MissionControlSpaceBackend.isAvailable { return "Mission Control (Accessibility)" }
        if SkyLightSpaceBackend.isAvailable {
            return "SkyLight (private API) — grant Accessibility for the reliable Mission Control path"
        }
        return "current space only — install yabai or grant Accessibility to create/switch desktops"
    }

    func spaceSpecIsNew(_ spec: SpaceSpec) -> Bool { spec.isNew }

    func gotoSpace(_ spec: SpaceSpec) {
        switch spec {
        case .index(let i):
            backend?.gotoSpace(index: i)
        case .new, .none:
            break
        }
    }

    /// Create + switch to a new desktop, then run `done(success)`.
    func gotoNewUserSpace(done: @escaping (Bool) -> Void) {
        guard let backend else {
            Notify.send(title: "Spacestrator",
                        body: "Can't create a new desktop (no space backend). Install yabai or grant permissions.")
            done(false)
            return
        }
        backend.gotoNewUserSpace { success in
            if !success {
                Notify.send(title: "Spacestrator",
                            body: "New desktop was not detected; launches will run on the current space.")
            }
            done(success)
        }
    }
}
