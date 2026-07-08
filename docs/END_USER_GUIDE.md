# Spacestrator — end-user guide

Spacestrator is a **menu bar app** for macOS. It launches a predefined set of apps (IDE, browser, Finder, Simulator, etc.) onto a dedicated desktop when you pick a **project**.

There is no Dock icon and no main window — you control it from the **▦ icon** at the top-right of your screen.

---

## Requirements

- macOS **Ventura (13.0)** or later
- Apple Silicon or Intel Mac

Optional but recommended:

- **[yabai](https://github.com/koekeishiya/yabai)** — reliable Mission Control space switching (`brew install koekeishiya/formulae/yabai`)

---

## Install

### Option A — Homebrew (easiest, once the maintainer publishes a cask)

```bash
brew install --cask YOURNAME/tap/spacestrator
```

Then open it:

```bash
open /Applications/Spacestrator.app
```

### Option B — Download a release (recommended)

1. Go to **Releases** on the GitHub repo:  
   `https://github.com/YOURNAME/spacestrator/releases`
2. Download `Spacestrator-x.y.z.dmg`.
3. Open the DMG and drag **Spacestrator** to **Applications**.
4. Launch from Applications (or Spotlight: type `Spacestrator`).

First launch may ask you to approve the app in **System Settings → Privacy & Security**.

### Option C — Build from source (developers)

Requires Xcode or Swift Command Line Tools.

```bash
git clone https://github.com/YOURNAME/spacestrator.git
cd spacestrator
scripts/build.sh 0.1.0
open build/Spacestrator.app
```

If macOS blocks an unsigned local build:

```bash
xattr -dr com.apple.quarantine build/Spacestrator.app
open build/Spacestrator.app
```

---

## First run — permissions

Spacestrator may request:

| Permission | Why |
| ---------- | --- |
| **Accessibility** | Auto-dismisses JetBrains / Android Studio “Open Project” dialogs |
| **Screen Recording** | Only needed if you use “Snapshot windows” to capture window titles |
| **Automation (Apple Events)** | Controls Finder, Chrome, and other apps to open projects |

Grant these in **System Settings → Privacy & Security**. Relaunch Spacestrator if prompted.

Check status from Terminal:

```bash
spacestrator --status
```

*(If `spacestrator` is not on your PATH, use `/Applications/Spacestrator.app/Contents/MacOS/Spacestrator --status`.)*

---

## Run at login (always available)

So **⌘⌥P** works without manually starting the app each day:

1. **System Settings → General → Login Items**
2. Under **Open at Login**, click **+**
3. Choose **Spacestrator** from Applications

---

## Terminal command (optional)

To type `spacestrator` in Terminal:

```bash
mkdir -p ~/bin
ln -sf /Applications/Spacestrator.app/Contents/MacOS/Spacestrator ~/bin/spacestrator
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Commands:

```bash
spacestrator              # start the menu bar app
spacestrator --status     # config path, projects, permissions
spacestrator --version
spacestrator --help
```

---

## Daily use

### Menu bar

Click the **▦** icon:

| Item | Action |
| ---- | ------ |
| **Your projects** | Click one to load it (creatates/switches space, launches apps) |
| **Project picker…** | Searchable list (also **⌘⌥P**) |
| **Manage projects → New project from template…** | Creates starter JSON in your config folder |
| **Manage projects → Open configs folder…** | Opens `~/.spacestrator/configs` in Finder |
| **Manage projects → Reload configs** | Re-reads JSON after you edit files |
| **Quit Spacestrator** | **⌘Q** from the menu |

### Keyboard shortcuts

| Shortcut | Action |
| -------- | ------ |
| **⌘⌥P** | Open Spacestrator menu at cursor |
| **⌘⌥⌃S** | Snapshot windows per space (prints JSON to console) |

*Shortcuts work only while Spacestrator is running.*

### What happens when you load a project

1. **Space** — `"space": "new"` creates a fresh desktop; a number switches to that desktop; omitted = stay on current space.
2. **Launch** — Opens each app in your config (IDE with project path, Chrome with profile, Finder folder, Simulator, etc.).
3. **Dialogs** — JetBrains IDEs get the “Open Project” dialog handled automatically.
4. **Notify** — A notification confirms the project loaded.

---

## Configure a project

Configs live in:

```
~/.spacestrator/configs/*.json
```

Each file is one project. Example:

```json
{
  "name": "My App",
  "space": "new",
  "apps": [
    { "type": "app", "name": "Cursor", "path": "/Users/you/projects/my-app" },
    { "type": "chrome", "name": "Google Chrome", "profile": "Work" },
    { "type": "folder", "name": "Finder", "path": "/Users/you/projects/my-app" },
    { "type": "simulator", "name": "Simulator", "device": "iPhone 15" }
  ]
}
```

**Quick start:** Menu bar → **Manage projects → New project from template…** → edit the file → **Reload configs**.

See the main [README](../README.md) for the full schema and built-in app catalog.

---

## Troubleshooting

### I don’t see the menu bar icon

- The menu bar may be full (notch / many icons) — hide other menu bar apps or use Ice/Bartender.
- Confirm the app is running: `spacestrator --status`
- Quit and reopen: `open /Applications/Spacestrator.app`

### Gatekeeper blocked the app

For downloaded unsigned or quarantined builds:

```bash
xattr -dr com.apple.quarantine /Applications/Spacestrator.app
```

### Spaces don’t switch reliably

Install **yabai** and ensure it is running. Without it, Spacestrator falls back to private macOS APIs that may be less reliable for *creating* new spaces.

### IDE “Open Project” dialog still appears

Grant **Accessibility** to Spacestrator in System Settings, then relaunch.

### Hotkey ⌘⌥P does nothing

- Spacestrator must be running (add to Login Items).
- Another app may use the same shortcut — quit conflicting apps or ask the maintainer to make the shortcut configurable.

---

## Uninstall

```bash
# Quit the app first (menu bar → Quit Spacestrator)
rm -rf /Applications/Spacestrator.app
rm -rf ~/.spacestrator          # optional — removes your project configs
rm -f ~/bin/spacestrator        # if you created the symlink
```

With Homebrew:

```bash
brew uninstall --cask spacestrator
```

---

## Get help

- **Issues:** `https://github.com/YOURNAME/spacestrator/issues`
- **Docs:** [README](../README.md) for developers and config reference
