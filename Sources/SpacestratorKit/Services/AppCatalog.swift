import Foundation

/// A curated catalog of common macOS apps so users rarely have to hunt for a
/// bundle id. It serves two jobs:
///   1. Improves focus reliability for apps whose process name differs from the
///      display name (JetBrains IDEs, Cursor, Teams, …) — AppManager consults it
///      when resolving a running app.
///   2. Powers the "common apps" reference and the new-project template.
///
/// Resolution still works for apps NOT in this list: AppManager falls back to
/// matching by display name, and `open -a "Name"` launches by name. Any entry can
/// also be overridden per-app in JSON with an explicit `"bundleId"`.
public enum AppCatalog {

    public struct Entry {
        public let name: String          // display name (what you put in JSON "name")
        public let bundleId: String
        public let suggestedType: AppType
        public let category: String
        /// JetBrains-family + Android Studio show an "Open Project" dialog when
        /// opening a folder in a running instance; default to dismissing it.
        public let opensProjectDialog: Bool

        init(_ name: String, _ bundleId: String, _ category: String,
             type: AppType = .app, projectDialog: Bool = false) {
            self.name = name
            self.bundleId = bundleId
            self.category = category
            self.suggestedType = type
            self.opensProjectDialog = projectDialog
        }
    }

    public static let entries: [Entry] = [
        // Browsers
        Entry("Google Chrome", "com.google.Chrome", "Browsers", type: .chrome),
        Entry("Safari", "com.apple.Safari", "Browsers"),
        Entry("Arc", "company.thebrowser.Browser", "Browsers"),
        Entry("Firefox", "org.mozilla.firefox", "Browsers"),
        Entry("Microsoft Edge", "com.microsoft.edgemac", "Browsers"),
        Entry("Brave Browser", "com.brave.Browser", "Browsers"),

        // Editors & IDEs
        Entry("Visual Studio Code", "com.microsoft.VSCode", "Editors & IDEs"),
        Entry("Cursor", "com.todesktop.230313mzl4w4u92", "Editors & IDEs"),
        Entry("Zed", "dev.zed.Zed", "Editors & IDEs"),
        Entry("Sublime Text", "com.sublimetext.4", "Editors & IDEs"),
        Entry("Nova", "com.panic.Nova", "Editors & IDEs"),
        Entry("Xcode", "com.apple.dt.Xcode", "Editors & IDEs"),
        Entry("Android Studio", "com.google.android.studio", "Editors & IDEs", projectDialog: true),
        Entry("IntelliJ IDEA", "com.jetbrains.intellij", "Editors & IDEs", projectDialog: true),
        Entry("IntelliJ IDEA CE", "com.jetbrains.intellij.ce", "Editors & IDEs", projectDialog: true),
        Entry("PyCharm", "com.jetbrains.pycharm", "Editors & IDEs", projectDialog: true),
        Entry("PyCharm CE", "com.jetbrains.pycharm.ce", "Editors & IDEs", projectDialog: true),
        Entry("WebStorm", "com.jetbrains.WebStorm", "Editors & IDEs", projectDialog: true),
        Entry("PhpStorm", "com.jetbrains.PhpStorm", "Editors & IDEs", projectDialog: true),
        Entry("GoLand", "com.jetbrains.goland", "Editors & IDEs", projectDialog: true),
        Entry("CLion", "com.jetbrains.CLion", "Editors & IDEs", projectDialog: true),
        Entry("RubyMine", "com.jetbrains.rubymine", "Editors & IDEs", projectDialog: true),
        Entry("Rider", "com.jetbrains.rider", "Editors & IDEs", projectDialog: true),
        Entry("DataGrip", "com.jetbrains.datagrip", "Editors & IDEs", projectDialog: true),

        // Terminals
        Entry("Terminal", "com.apple.Terminal", "Terminals"),
        Entry("iTerm", "com.googlecode.iterm2", "Terminals"),
        Entry("Warp", "dev.warp.Warp-Stable", "Terminals"),
        Entry("Ghostty", "com.mitchellh.ghostty", "Terminals"),
        Entry("kitty", "net.kovidgoyal.kitty", "Terminals"),
        Entry("Alacritty", "org.alacritty", "Terminals"),
        Entry("WezTerm", "com.github.wez.wezterm", "Terminals"),

        // Communication
        Entry("Slack", "com.tinyspeck.slackmacgap", "Communication"),
        Entry("Discord", "com.hnc.Discord", "Communication"),
        Entry("Zoom", "us.zoom.xos", "Communication"),
        Entry("Microsoft Teams", "com.microsoft.teams2", "Communication"),
        Entry("Telegram", "ru.keepcoder.Telegram", "Communication"),
        Entry("WhatsApp", "net.whatsapp.WhatsApp", "Communication"),
        Entry("Signal", "org.whispersystems.signal-desktop", "Communication"),

        // Design
        Entry("Figma", "com.figma.Desktop", "Design"),
        Entry("Sketch", "com.bohemiancoding.sketch3", "Design"),

        // Productivity & notes
        Entry("Notion", "notion.id", "Productivity"),
        Entry("Obsidian", "md.obsidian", "Productivity"),
        Entry("Linear", "com.linear", "Productivity"),
        Entry("Things", "com.culturedcode.ThingsMac", "Productivity"),
        Entry("Notes", "com.apple.Notes", "Productivity"),
        Entry("Spotify", "com.spotify.client", "Productivity"),

        // Dev tools & databases
        Entry("TablePlus", "com.tinyapp.TablePlus", "Dev tools"),
        Entry("Postman", "com.postmanlab.mac", "Dev tools"),
        Entry("Docker", "com.docker.docker", "Dev tools"),
        Entry("GitHub Desktop", "com.github.GitHubClient", "Dev tools"),
        Entry("Tower", "com.fournova.Tower3", "Dev tools"),

        // Apple system
        Entry("Finder", "com.apple.finder", "System", type: .folder),
        Entry("Simulator", "com.apple.iphonesimulator", "System", type: .simulator),
        Entry("Mail", "com.apple.mail", "System"),
        Entry("Calendar", "com.apple.iCal", "System"),
        Entry("Preview", "com.apple.Preview", "System")
    ]

    /// Case-insensitive lookup by display name.
    public static func entry(forName name: String) -> Entry? {
        let key = name.lowercased()
        return entries.first { $0.name.lowercased() == key }
    }

    /// Bundle id for a display name, if known.
    public static func bundleId(forName name: String) -> String? {
        entry(forName: name)?.bundleId
    }

    /// name -> bundleId map (used to seed AppManager's resolution hints).
    public static var bundleHints: [String: String] {
        Dictionary(entries.map { ($0.name, $0.bundleId) }, uniquingKeysWith: { a, _ in a })
    }

    /// Entries grouped by category, for the reference list / docs.
    public static var byCategory: [(String, [Entry])] {
        let order = ["Browsers", "Editors & IDEs", "Terminals", "Communication",
                     "Design", "Productivity", "Dev tools", "System"]
        return order.compactMap { cat in
            let items = entries.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}
