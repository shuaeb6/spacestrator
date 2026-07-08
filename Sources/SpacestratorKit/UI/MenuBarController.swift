import Foundation
import AppKit
import Carbon.HIToolbox

/// Menu bar status item: lists projects and utility actions.
/// Ports ui/menuBarApp.lua, rebranded as Spacestrator with quick "add project" helpers.
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?

    func start() {
        WindowTracker.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let statusItem else {
            Notify.send(title: "Spacestrator", body: "Could not create menubar item")
            return
        }
        statusItem.isVisible = true

        // Compact, native look: an SF Symbol template image. If the symbol can't be
        // created (older OS), fall back to a visible text title so the item is never blank.
        if let image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Spacestrator") {
            image.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.imagePosition = .imageLeading
        } else {
            statusItem.button?.title = "Spacestrator"
        }
        statusItem.button?.toolTip = "Spacestrator"
        refreshMenu()
        Log.info("Menu bar item ready — look for the icon at the top-right of the screen.")

        // ⌘⌥P → pop the menu at the mouse.
        HotKeyCenter.shared.bind(keyCode: UInt32(kVK_ANSI_P),
                                 modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
            self?.popupAtMouse()
        }
    }

    func refreshMenu() {
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Branded, disabled header.
        let header = NSMenuItem(title: "Spacestrator", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // Projects.
        let slugs = WorkspaceStore.listProjectSlugs()
        if slugs.isEmpty {
            let item = NSMenuItem(title: "No projects yet — use \u{201C}New project\u{2026}\u{201D} below",
                                  action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for slug in slugs {
                let cfg = WorkspaceStore.loadProjectConfig(slug)
                let title = cfg?.name ?? slug
                let item = NSMenuItem(title: title, action: #selector(loadProjectAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = slug
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        addAction(menu, "Project picker\u{2026}", #selector(showPickerAction), key: "p")

        // Adding / editing projects.
        let manage = NSMenu()
        addAction(manage, "New project from template\u{2026}", #selector(newProjectAction))
        addAction(manage, "Open configs folder\u{2026}", #selector(openConfigsAction))
        addAction(manage, "Reload configs", #selector(reloadAction))
        let manageItem = NSMenuItem(title: "Manage projects", action: nil, keyEquivalent: "")
        manageItem.submenu = manage
        menu.addItem(manageItem)

        // Snapshots.
        let snap = NSMenu()
        addAction(snap, "Print to console (JSON)", #selector(snapshotConsoleAction))
        addAction(snap, "Write to /tmp/spacestrator-snapshot.json", #selector(snapshotFileAction))
        let snapItem = NSMenuItem(title: "Snapshot windows", action: nil, keyEquivalent: "")
        snapItem.submenu = snap
        menu.addItem(snapItem)

        menu.addItem(.separator())
        addAction(menu, "Keep project windows on their desktop", #selector(fixSpaceSwitchAction))
        addAction(menu, "Permissions\u{2026}", #selector(permissionsAction))
        addAction(menu, "Quit Spacestrator", #selector(quitAction), key: "q")

        return menu
    }

    private func addAction(_ menu: NSMenu, _ title: String, _ selector: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    func popupAtMouse() {
        guard let menu = statusItem?.menu else { return }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Actions

    @objc private func loadProjectAction(_ sender: NSMenuItem) {
        guard let slug = sender.representedObject as? String else { return }
        WorkspaceLoader.loadProject(slug)
    }

    @objc private func showPickerAction() {
        ProjectPicker.shared.show()
    }

    /// Create a starter JSON and open it in the default text editor.
    @objc private func newProjectAction() {
        let path = WorkspaceStore.createTemplateProject()
        Shell.open(["-t", path])               // -t = default text editor
        refreshMenu()
        Notify.send(title: "Spacestrator", body: "Created \(path). Edit it, then Reload configs.")
    }

    @objc private func openConfigsAction() {
        let dir = WorkspaceStore.ensureConfigDir()
        Shell.open([dir])
    }

    @objc private func reloadAction() {
        refreshMenu()
        Notify.send(title: "Spacestrator", body: "Menu refreshed")
    }

    @objc private func snapshotConsoleAction() {
        WorkspaceSnapshot.snapshotWorkspaces()
    }

    @objc private func snapshotFileAction() {
        WorkspaceSnapshot.snapshotWorkspacesToFile(path: "/tmp/spacestrator-snapshot.json")
    }

    @objc private func fixSpaceSwitchAction() {
        let ok = SpaceSwitchPrefs.disable()
        Notify.send(title: "Spacestrator",
                    body: ok
                        ? "Done — new project windows will now stay on the desktop they open on."
                        : "Couldn't update the macOS setting (try System Settings → Desktop & Dock → Mission Control).")
    }

    @objc private func permissionsAction() {
        Permissions.ensureAccessibility(prompt: true)
        Permissions.ensureScreenRecording(prompt: true)
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
