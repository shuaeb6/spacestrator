# Spacestrator

A native macOS menu bar app that launches per-project sets of apps onto a
dedicated Mission Control space — IDEs opening a project folder, Chrome with a
named profile, Finder, the iOS Simulator — and auto-dismisses the
JetBrains/Android Studio "Open Project" dialog. It is a from-scratch Swift +
AppKit rewrite of a Hammerspoon config, built to ship **without** Hammerspoon
via Homebrew (Developer ID signed + notarized).

> **Why not the Mac App Store?** The core features depend on private SkyLight
> (Spaces) calls, cross-app Accessibility automation, and launching arbitrary
> apps — all forbidden by the App Store sandbox. The same constraint is why
> Hammerspoon, yabai, Rectangle, and AltTab all distribute outside the Store.
> Notarization (used here) is an automated malware scan, not Store review, and
> permits these capabilities.

## Running it

Spacestrator is a **menu-bar app**, not a terminal program — so by design it has no
Dock icon and no window, and it doesn't "take over" a terminal. Once it's running
you control it from the **▦ icon at the top-right of your screen** (like Hammerspoon).

- **Recommended:** `open build/Spacestrator.app` (or move it to `/Applications` and
  open it). The icon appears in the menu bar and the app detaches from the terminal.
- **Dev mode:** `swift run` prints a banner and runs the same app, but keeps the
  terminal attached (Ctrl-C quits). The menu-bar icon still appears.

When launched from a terminal it prints a styled banner and supports a few flags:

```bash
Spacestrator            # launch the menu-bar app (prints the banner)
Spacestrator --status   # config dir, projects, space backend, permissions — then exit
Spacestrator --version
Spacestrator --help
```

> **"I don't see the menu-bar icon."** It's almost always one of: (1) you ran it and
> it's actually there but tucked behind the notch / off-screen because the menu bar
> is full — quit some menu-bar apps or use a manager like Ice/Bartender to reveal it;
> (2) you launched the bare binary in a way that got killed (use `open …app` or
> `swift run`); or (3) Gatekeeper quarantined an unsigned copy — `xattr -dr
> com.apple.quarantine build/Spacestrator.app` and reopen. Run `Spacestrator --status`
> to confirm the app is wired up correctly.

## How it works

Spacestrator lives in your menu bar (a small stacked-rectangles icon). Each
*project* is a JSON file in `~/.spacestrator/configs/`. When you pick a project:

1. **Space** — if the project's `space` is `"new"`, it creates a fresh
   Mission Control desktop and switches to it; if it's a number, it switches to
   that desktop; if omitted, it stays put.
2. **Launch** — it opens each app in the `apps` list on a short stagger so
   windows land on the right space and dialogs settle. An `app` with a `path`
   opens that folder as a project in the IDE; a `chrome` entry opens Chrome with
   a named profile; a `folder` reveals a path in Finder; a `simulator` boots an
   iOS Simulator device.
3. **Dialogs** — for JetBrains IDEs / Android Studio, it auto-clicks the
   "Open Project → New Window / This Window" dialog so you don't have to.
4. **Notify** — a notification confirms the project loaded.

Hotkeys: **⌘⌥P** opens the project picker, **⌘⌥⌃S** snapshots which windows are
on which space (as JSON).

## The menu bar

Click the icon for:

- **Your projects** — click any to load it.
- **Project picker…** (⌘⌥P) — a searchable, keyboard-driven chooser.
- **Manage projects**
  - *New project from template…* — creates a starter JSON and opens it in your
    editor.
  - *Open configs folder…* — reveals `~/.spacestrator/configs` in Finder.
  - *Reload configs* — re-reads the folder after you add/edit files.
- **Snapshot windows** — print per-space window JSON to the console or `/tmp`.
- **Permissions…** — re-trigger the Accessibility / Screen Recording prompts.
- **Quit Spacestrator** (⌘Q).

## Adding an app or a new project

There's no separate config app — projects are just small JSON files, so adding
one takes a few seconds:

1. Menu bar → **Manage projects → New project from template…**. This drops a
   ready-to-edit file in `~/.spacestrator/configs/` and opens it.
2. Edit the `apps` array. To **add an app**, append an entry. The only required
   field for a plain app is `name` (the app's display name, e.g. `"Slack"`):

   ```jsonc
   { "type": "app", "name": "Slack" }                              // just launch/focus it
   { "type": "app", "name": "Cursor", "path": "/abs/project" }     // open a folder as a project
   { "type": "chrome", "name": "Google Chrome", "profile": "Work" }// Chrome with a profile
   { "type": "folder", "name": "Finder", "path": "/abs/project" }  // reveal in Finder
   { "type": "simulator", "name": "Simulator", "device": "iPhone 15" }
   ```

3. Save, then menu bar → **Reload configs**. Your project appears in the menu.

You usually **don't need a bundle id** — Spacestrator matches by app name and,
for ~60 common apps, knows the bundle id already (see the list below). If an app
isn't found (uncommon process name), add `"bundleId": "com.vendor.App"`. Find any
app's id in Terminal with:

```bash
osascript -e 'id of app "Notion"'
```

### Most common apps (built in)

These names work out of the box — Spacestrator already knows their bundle ids and
sensible defaults (e.g. JetBrains IDEs auto-dismiss the open-project dialog):

| Category        | Apps |
| --------------- | ---- |
| Browsers        | Google Chrome, Safari, Arc, Firefox, Microsoft Edge, Brave Browser |
| Editors & IDEs  | Visual Studio Code, Cursor, Zed, Sublime Text, Nova, Xcode, Android Studio, IntelliJ IDEA (+CE), PyCharm (+CE), WebStorm, PhpStorm, GoLand, CLion, RubyMine, Rider, DataGrip |
| Terminals       | Terminal, iTerm, Warp, Ghostty, kitty, Alacritty, WezTerm |
| Communication   | Slack, Discord, Zoom, Microsoft Teams, Telegram, WhatsApp, Signal |
| Design          | Figma, Sketch |
| Productivity    | Notion, Obsidian, Linear, Things, Notes, Spotify |
| Dev tools       | TablePlus, Postman, Docker, GitHub Desktop, Tower |
| System          | Finder, Simulator, Mail, Calendar, Preview |

The catalog lives in `Sources/SpacestratorKit/Services/AppCatalog.swift` — add
your own entries there, or just use any app by name/`bundleId` in JSON.

## Config schema

```jsonc
{
  "name": "Project 1",          // display name
  "space": "new",               // "new" | <1-based desktop index> | omit
  "apps": [
    { "type": "app",    "name": "Cursor", "path": "/abs/project",
      "newWindow": true, "bundleId": "...", "openProjectDialog": "newWindow",
      "openProjectDialogButton": "New Window" },
    { "type": "chrome", "name": "Google Chrome", "profile": "work profile",
      "profileDirectory": "Profile 3" },
    { "type": "folder", "name": "Finder", "path": "/abs/project" },
    { "type": "simulator", "name": "Simulator", "device": "iPhone 15" }
  ]
}
```

## How the original Lua maps to Swift

| Hammerspoon file                    | Swift equivalent                                       |
| ----------------------------------- | ------------------------------------------------------ |
| `init.lua`                          | `SpacestratorKit/AppDelegate.swift` + `Spacestrator/main.swift` |
| `ui/menuBarApp.lua`                 | `SpacestratorKit/UI/MenuBarController.swift`           |
| `ui/projectPicker.lua`              | `SpacestratorKit/UI/ProjectPicker.swift` (NSPanel + table) |
| `engine/workspace.lua` (data)       | `SpacestratorKit/Config/WorkspaceStore.swift`          |
| `engine/workspace.lua` (loadProject)| `SpacestratorKit/Engine/WorkspaceLoader.swift`         |
| `engine/workspaceSnapshot.lua`      | `SpacestratorKit/Engine/WorkspaceSnapshot.swift`       |
| `services/appManager.lua`           | `SpacestratorKit/Services/AppManager.swift`            |
| `services/spaceManager.lua`         | `SpacestratorKit/Services/SpaceManager.swift` (+ backends) |
| `services/chromeProfile.lua`        | `SpacestratorKit/Services/ChromeProfile.swift`         |
| `services/jetbrainsOpenProject.lua` | `SpacestratorKit/Services/JetBrainsOpenProject.swift`  |
| `services/windowTracker.lua`        | `SpacestratorKit/Services/WindowTracker.swift`         |
| *(new)* common-apps catalog         | `SpacestratorKit/Services/AppCatalog.swift`            |
| `configs/projectX.json`             | unchanged — same schema (`examples/projectX.json`)     |
| `hs.spaces` (private API)           | `CSkyLight/` shim + `SpacestratorKit/Services/SkyLightSpaceBackend.swift` |
| `hs.notify` / `hs.hotkey`           | `SpacestratorKit/Support/Notify.swift` / `HotKeyCenter.swift` |

Your existing `*.json` configs work as-is. The app reads `~/.spacestrator` by
default but still falls back to a legacy `~/.workspace` dir (and honors both
`SPACESTRATOR_HOME` and `WORKSPACE_HOME`), so an existing setup keeps working —
or `mv ~/.workspace ~/.spacestrator` to adopt the new name.

## The Spaces backend (important)

macOS has no public API to create/switch Mission Control spaces. Two backends ship:

1. **yabai (recommended).** If `yabai` is installed, the app shells out to it.
   `space --create` and `space --focus` work with SIP **enabled** — this app never
   moves windows across spaces, so you do *not* need to disable SIP.
2. **SkyLight (fallback).** Calls private SkyLight symbols directly via the
   `CSkyLight` shim (bound at runtime with `dlopen`/`dlsym`, so nothing private is
   linked at build time). The read/switch path is reliable; **space creation is
   version-sensitive** and may need adjustment on future macOS releases — which is
   exactly why yabai is preferred.

If neither is available, projects still load — just on the current space.

## Build

Requires Xcode or the Swift toolchain (Command Line Tools).

```bash
swift run                          # dev run (unsigned, menu-bar only)
swift test                         # run the unit tests

python3 scripts/make_icon.py       # writes Resources/icon-1024.png
scripts/make_icon.sh               # writes Resources/AppIcon.icns (macOS only)
scripts/build.sh 0.1.0             # assembles build/Spacestrator.app
open build/Spacestrator.app
```

The project is split into a `SpacestratorKit` library (all logic) and a thin
`Spacestrator` executable (just `main.swift`), so the core is unit-testable.

## Tests

`Tests/SpacestratorKitTests` covers config decoding (polymorphic `space`, lenient
`openProjectDialog`, type defaults), Chrome profile resolution (name/gaia/user/dir
matching against a fixture `Local State`, plus fallbacks), the app catalog, and
`WorkspaceStore` listing/loading via a temporary `SPACESTRATOR_HOME`. Run with
`swift test`; they also run in CI.

## CI & releases

- `.github/workflows/ci.yml` — builds and tests on `macos-14` for pushes/PRs.
- `.github/workflows/release.yml` — on a `v*` tag: imports your Developer ID cert,
  builds icon + app, signs, notarizes, staples, packages a DMG, and publishes a
  GitHub Release (printing the cask `version`/`sha256`).

Release secrets: `DEVELOPER_ID_CERT_P12`, `DEVELOPER_ID_CERT_PASSWORD`,
`KEYCHAIN_PASSWORD`, `SIGN_IDENTITY`, `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`,
`NOTARY_PASSWORD`. Ship with:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## Distribute via Homebrew

After a release exists, fill in `version`, `sha256`, and the URL in
`packaging/homebrew/spacestrator.rb`, put it in your tap
(`YOURNAME/homebrew-tap`), and users install with:

```bash
brew install --cask YOURNAME/tap/spacestrator
```

## Before you ship — find/replace

- `com.example.spacestrator` → your bundle id (in `Info.plist.template`, the
  `Log` subsystem, the cask `zap`).
- `YOURNAME` / `YOUR NAME` → your GitHub handle / name (cask URL, `LICENSE`).
- `Resources/AppIcon.icns` is generated by `scripts/make_icon.sh`; replace
  `Resources/icon-1024.png` first to use your own artwork.

## Environment variables

- `SPACESTRATOR_HOME` (or legacy `WORKSPACE_HOME`) — override the config home.
- `WORKSPACE_TRACK_WINDOWS=1` — log focused-app changes (debugging).
