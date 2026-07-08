import Foundation
import CSkyLight

/// Fallback space backend using private SkyLight APIs directly (no yabai needed).
///
/// The READ + SWITCH path (enumerate user spaces on the active display, switch by
/// index) is reliable. The CREATE path is best-effort: SLSSpaceCreate's behaviour
/// varies across macOS versions, so if a new space can't be confirmed we report
/// failure and let the loader degrade gracefully (apps open on the current space).
final class SkyLightSpaceBackend: SpaceBackend {
    let name = "SkyLight"

    static var isAvailable: Bool { wo_skylight_available() }

    // MARK: - Topology

    /// Managed space ids (manageId / id64) for the active display, in order.
    private func userSpaceIDs() -> [UInt64] {
        guard let displays = wo_copy_managed_display_spaces()?.takeRetainedValue() as? [[String: Any]] else {
            return []
        }
        let activeDisplay = wo_active_display_identifier()?.takeRetainedValue() as String?

        // Prefer the active display; fall back to the first managed display.
        let chosen = displays.first(where: { ($0["Display Identifier"] as? String) == activeDisplay })
            ?? displays.first

        guard let spaces = chosen?["Spaces"] as? [[String: Any]] else { return [] }

        return spaces.compactMap { space in
            // type 0 == user/standard desktop; skip fullscreen tiles (type 4).
            let type = (space["type"] as? Int) ?? 0
            guard type == 0 else { return nil }
            if let id = space["ManagedSpaceID"] as? UInt64 { return id }
            if let id = space["id64"] as? UInt64 { return id }
            if let n = space["ManagedSpaceID"] as? NSNumber { return n.uint64Value }
            if let n = space["id64"] as? NSNumber { return n.uint64Value }
            return nil
        }
    }

    private func switchTo(spaceID: UInt64) {
        guard let display = wo_active_display_identifier()?.takeRetainedValue() else { return }
        wo_set_current_space(display, spaceID)
    }

    // MARK: - SpaceBackend

    func gotoSpace(index: Int) {
        let ids = userSpaceIDs()
        guard index >= 1, index <= ids.count else {
            Notify.send(title: "Spacestrator",
                        body: "No desktop at index \(index) (you have \(ids.count) user desktops)")
            return
        }
        switchTo(spaceID: ids[index - 1])
    }

    func gotoNewUserSpace(completion: @escaping (Bool) -> Void) {
        let before = Set(userSpaceIDs())
        let created = wo_create_space_on_active_display()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let afterIDs = self.userSpaceIDs()
            let newID = afterIDs.first(where: { !before.contains($0) }) ?? (created != 0 ? created : 0)
            if newID != 0 {
                self.switchTo(spaceID: newID)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { completion(true) }
            } else {
                completion(false)
            }
        }
    }
}
