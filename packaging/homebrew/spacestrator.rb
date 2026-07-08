cask "spacestrator" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/YOURNAME/spacestrator/releases/download/v#{version}/Spacestrator-#{version}.dmg"
  name "Spacestrator"
  desc "Per-project menu bar launcher for apps, spaces, and IDE projects on macOS"
  homepage "https://github.com/YOURNAME/spacestrator"

  depends_on macos: ">= :ventura"

  app "Spacestrator.app"

  # yabai is the recommended (optional) space-control backend. Without it the app
  # falls back to private SkyLight calls, and if those are unavailable it simply
  # launches projects on the current space.
  # depends_on cask: "yabai"   # uncomment to make it a hard dependency

  caveats <<~EOS
    Spacestrator needs a couple of macOS permissions to work fully:

      • Accessibility    — System Settings → Privacy & Security → Accessibility
                           (required to auto-dismiss IDE "Open Project" dialogs)
      • Screen Recording — System Settings → Privacy & Security → Screen Recording
                           (only needed to capture window titles in snapshots)

    Put your project configs in:  ~/.spacestrator/configs/*.json
    (Tip: use the menu bar → Manage projects → New project from template…)

    For robust Mission Control space switching, install yabai:
      brew install koekeishiya/formulae/yabai
  EOS

  zap trash: [
    "~/Library/Caches/com.example.spacestrator",
    "~/Library/Preferences/com.example.spacestrator.plist",
  ]
end
