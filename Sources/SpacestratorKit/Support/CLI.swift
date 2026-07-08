import Foundation
import AppKit

/// Terminal-facing front end. When Spacestrator is launched from a shell it prints
/// a styled banner (like other CLI tools) and supports --help / --version / --status.
/// When launched as a .app bundle (no TTY) the ANSI styling is dropped and the
/// output simply goes nowhere — the app just lives in the menu bar.
public enum CLI {

    public static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }

    private static var isTTY: Bool { isatty(STDOUT_FILENO) == 1 }

    // ANSI styling (no-ops when not a terminal).
    private static func s(_ text: String, _ codes: String) -> String {
        isTTY ? "\u{001B}[\(codes)m\(text)\u{001B}[0m" : text
    }
    private static func bold(_ t: String) -> String { s(t, "1") }
    private static func cyan(_ t: String) -> String { s(t, "1;36") }
    private static func magenta(_ t: String) -> String { s(t, "1;35") }
    private static func green(_ t: String) -> String { s(t, "1;32") }
    private static func dim(_ t: String) -> String { s(t, "2") }

    // MARK: - Banner

    /// Printed on normal startup, just before the menu-bar app takes over.
    public static func printBanner() {
        let v = version
        let configDir = WorkspaceStore.configDir()
        let count = WorkspaceStore.listProjectSlugs().count
        let backend = SpaceManager.detectedBackendName

        let logo = """
          \(magenta("▟█▙"))
         \(magenta("▟███▙"))   \(cyan("S P A C E S T R A T O R"))
          \(magenta("▜█▛"))    \(dim("per-project workspace launcher for macOS"))
        """

        print("")
        print(logo)
        print("  " + dim("v\(v)"))
        print("")
        print("  \(green("▸")) \(bold("Configs"))   \(configDir)  \(dim("(\(count) project\(count == 1 ? "" : "s"))"))")
        print("  \(green("▸")) \(bold("Spaces"))    \(backend)")
        print("  \(green("▸")) \(bold("Menu bar"))  running now — look for the \(bold("▦")) icon at the top‑right of your screen ↗")
        print("  \(green("▸")) \(bold("Hotkeys"))   ⌘⌥P picker    ⌘⌥⌃S snapshot")
        print("  \(green("▸")) \(bold("Quit"))      choose Quit from the menu (or Ctrl‑C here if you ran it in a terminal)")
        print("")
        if count == 0 {
            print("  " + dim("No projects yet. Add JSON to the configs folder, or use the menu:"))
            print("  " + dim("Manage projects → New project from template…"))
            print("")
        }
    }

    // MARK: - Subcommands

    public static func printVersion() {
        print("Spacestrator \(version)")
    }

    public static func printStatus() {
        let configDir = WorkspaceStore.configDir()
        let slugs = WorkspaceStore.listProjectSlugs()
        print(cyan("Spacestrator \(version) — status"))
        print("  Config dir:    \(configDir)")
        print("  Projects:      \(slugs.count)")
        for slug in slugs {
            let name = WorkspaceStore.loadProjectConfig(slug)?.name ?? slug
            print("    • \(name)  \(dim("(\(slug).json)"))")
        }
        print("  Space backend: \(SpaceManager.detectedBackendName)")
        print("  Accessibility: \(Permissions.ensureAccessibility(prompt: false) ? "granted" : "not granted")")
    }

    public static func printHelp() {
        print("""
        \(cyan("Spacestrator")) \(dim("v\(version)")) — per-project workspace launcher for macOS

        \(bold("USAGE"))
          Spacestrator               Launch the menu-bar app (lives in the menu bar)
          Spacestrator --status      Print config dir, projects, and backend, then exit
          Spacestrator --version     Print version and exit
          Spacestrator --help        Show this help

        \(bold("HOW IT RUNS"))
          Spacestrator is a menu-bar app. Once launched it shows a \(bold("▦")) icon at the
          top of your screen; click it to load projects. It has no Dock icon and no
          window — that's intentional.

          • As an app (recommended):  open /Applications/Spacestrator.app
          • From a terminal (dev):    swift run         (keeps this terminal attached)

        \(bold("CONFIG"))
          Projects live in:  \(WorkspaceStore.configDir())
          Each project is one .json file. Add apps to its "apps" array.

        \(bold("HOTKEYS"))
          ⌘⌥P   project picker
          ⌘⌥⌃S  snapshot windows-per-space to the console
        """)
    }
}
