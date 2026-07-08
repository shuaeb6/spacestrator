import Foundation
import AppKit
import ApplicationServices
import CSkyLight

/// Creates and switches Mission Control spaces the same way Hammerspoon's
/// `hs.spaces` does: by driving the Dock's Mission Control UI through the
/// Accessibility API. This is the version-independent path that keeps working on
/// current macOS (incl. 26.x), where the private `SLSSpaceCreate` route no longer
/// reliably produces a usable desktop.
///
/// Flow:
///   • Open Mission Control via `CoreDockSendNotification("com.apple.expose.awake")`.
///   • Walk the Dock's AX tree: app → "mc" → "mc.display" (matching the screen) →
///     "mc.spaces" → "mc.spaces.add" (the "+" button) / "mc.spaces.list" (the tiles).
///   • Press the "+" to add a desktop, then press the new tile to switch to it
///     (which also closes Mission Control).
///
/// Requires Accessibility permission (already requested at launch — it's the same
/// permission the IDE "Open Project" dialog automation needs).
final class MissionControlSpaceBackend: SpaceBackend {
    let name = "Mission Control (Accessibility)"

    /// How long Mission Control's AX elements may take to appear / update.
    private let settleTimeout: TimeInterval = 2.5
    private let pollInterval: TimeInterval = 0.1
    /// Small pause after a switch so windows launched next land on the new space.
    private let postSwitchSettle: TimeInterval = 0.6

    /// Available whenever we're allowed to drive the Dock. The private SkyLight
    /// create path is intentionally not used here.
    static var isAvailable: Bool { AXIsProcessTrusted() }

    // MARK: - SpaceBackend

    func gotoSpace(index: Int) {
        guard ensureTrusted() else { return }
        let displayID = mainDisplayID()
        openMissionControl()
        waitFor({ self.spacesList(displayID: displayID) != nil }, timeout: settleTimeout) { ok in
            guard ok, let list = self.spacesList(displayID: displayID) else {
                self.closeMissionControl()
                return
            }
            let tiles = self.axChildren(list)
            guard index >= 1, index <= tiles.count else {
                self.closeMissionControl()
                Notify.send(title: "Spacestrator",
                            body: "No desktop at index \(index) (you have \(tiles.count)).")
                return
            }
            let target = tiles[index - 1]
            self.pressTileConfirmingSwitch({ () -> AXUIElement? in
                let current = self.spacesList(displayID: displayID).map { self.axChildren($0) } ?? []
                // Re-find the same element by identity; fall back to the same index.
                if let match = current.first(where: { CFEqual($0, target) }) { return match }
                return current.indices.contains(index - 1) ? current[index - 1] : nil
            }, attemptsLeft: 3) { _ in }
        }
    }

    func gotoNewUserSpace(completion: @escaping (Bool) -> Void) {
        guard ensureTrusted() else { completion(false); return }
        let displayID = mainDisplayID()
        openMissionControl()

        waitFor({ self.addButton(displayID: displayID) != nil }, timeout: settleTimeout) { ready in
            guard ready, let add = self.addButton(displayID: displayID) else {
                self.closeMissionControl()
                completion(false)
                return
            }

            // Snapshot the existing tiles so we can identify the freshly added one.
            // A new desktop is inserted after the other desktops but *before* any
            // full-screen spaces, so it is not necessarily the last tile.
            let beforeTiles = self.spacesList(displayID: displayID).map { self.axChildren($0) } ?? []
            self.press(add)

            self.waitFor({
                guard let list = self.spacesList(displayID: displayID) else { return false }
                return self.axChildren(list).count > beforeTiles.count
            }, timeout: self.settleTimeout) { grew in
                guard grew else {
                    self.closeMissionControl()
                    completion(false)
                    return
                }
                // Let the new tile finish animating in before we press it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.pressTileConfirmingSwitch({
                        self.newlyAddedTile(displayID: displayID, before: beforeTiles)
                    }, attemptsLeft: 3, completion: completion)
                }
            }
        }
    }

    /// The tile present now but not in `before` (the desktop just created by "+"),
    /// with sensible fallbacks if AX element identity can't be established.
    private func newlyAddedTile(displayID: CGDirectDisplayID, before: [AXUIElement]) -> AXUIElement? {
        guard let list = spacesList(displayID: displayID) else { return nil }
        let now = axChildren(list)
        let added = now.filter { candidate in !before.contains { CFEqual($0, candidate) } }
        if let newTile = added.last { return newTile }
        // Fallbacks: the tile at the old count index (new desktop slots in there
        // when full-screen spaces are present), else the last tile.
        if now.indices.contains(before.count) { return now[before.count] }
        return now.last
    }

    /// Press a space tile and confirm the switch by observing Mission Control
    /// close. If it doesn't close, the press didn't register — retry.
    private func pressTileConfirmingSwitch(_ provider: @escaping () -> AXUIElement?,
                                           attemptsLeft: Int,
                                           completion: @escaping (Bool) -> Void) {
        guard let tile = provider() else {
            closeMissionControl()
            completion(false)
            return
        }
        press(tile)
        waitFor({ self.missionControlGroup() == nil }, timeout: 1.2) { closed in
            if closed {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.postSwitchSettle) {
                    completion(true)
                }
            } else if attemptsLeft > 1 {
                self.pressTileConfirmingSwitch(provider, attemptsLeft: attemptsLeft - 1, completion: completion)
            } else {
                self.closeMissionControl()
                completion(false)
            }
        }
    }

    // MARK: - Mission Control toggling

    private func openMissionControl() {
        if missionControlGroup() == nil {
            wo_core_dock_send_notification("com.apple.expose.awake" as CFString)
        }
    }

    private func closeMissionControl() {
        if missionControlGroup() != nil {
            wo_core_dock_send_notification("com.apple.expose.awake" as CFString)
        }
    }

    // MARK: - AX traversal of the Dock

    private func dockElement() -> AXUIElement? {
        guard let dock = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        return AXUIElementCreateApplication(dock.processIdentifier)
    }

    /// The "mc" group only exists while Mission Control is on-screen.
    private func missionControlGroup() -> AXUIElement? {
        guard let dock = dockElement() else { return nil }
        return firstChild(of: dock, identifier: "mc")
    }

    private func displayGroup(displayID: CGDirectDisplayID) -> AXUIElement? {
        guard let mc = missionControlGroup() else { return nil }
        let displays = axChildren(mc).filter { identifier($0) == "mc.display" }
        return displays.first(where: { axInt($0, "AXDisplayID") == Int(displayID) }) ?? displays.first
    }

    private func spacesGroup(displayID: CGDirectDisplayID) -> AXUIElement? {
        guard let display = displayGroup(displayID: displayID) else { return nil }
        return firstChild(of: display, identifier: "mc.spaces")
    }

    private func spacesList(displayID: CGDirectDisplayID) -> AXUIElement? {
        guard let spaces = spacesGroup(displayID: displayID) else { return nil }
        return firstChild(of: spaces, identifier: "mc.spaces.list")
    }

    private func addButton(displayID: CGDirectDisplayID) -> AXUIElement? {
        guard let spaces = spacesGroup(displayID: displayID) else { return nil }
        return firstChild(of: spaces, identifier: "mc.spaces.add")
    }

    // MARK: - AX helpers

    private func axChildren(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else { return [] }
        return children
    }

    private func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func axInt(_ element: AXUIElement, _ attribute: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }

    private func identifier(_ element: AXUIElement) -> String? {
        axString(element, kAXIdentifierAttribute as String)
    }

    private func firstChild(of element: AXUIElement, identifier id: String) -> AXUIElement? {
        axChildren(element).first { identifier($0) == id }
    }

    private func press(_ element: AXUIElement) {
        AXUIElementPerformAction(element, kAXPressAction as CFString)
    }

    // MARK: - Misc

    private func mainDisplayID() -> CGDirectDisplayID {
        if let screen = NSScreen.main,
           let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return CGDirectDisplayID(number.uint32Value)
        }
        return CGMainDisplayID()
    }

    private func ensureTrusted() -> Bool {
        if AXIsProcessTrusted() { return true }
        Notify.send(title: "Spacestrator",
                    body: "Grant Accessibility to create/switch desktops (System Settings → Privacy → Accessibility).")
        return false
    }

    /// Poll `condition` on the main queue until true or `timeout` elapses.
    private func waitFor(_ condition: @escaping () -> Bool,
                         timeout: TimeInterval,
                         then completion: @escaping (Bool) -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        func tick() {
            if condition() { completion(true); return }
            if Date() >= deadline { completion(false); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { tick() }
        }
        tick()
    }
}
