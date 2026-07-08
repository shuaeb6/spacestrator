import Foundation

/// Controls the macOS "When switching to an application, switch to a Space with
/// open windows for the application" behavior (a.k.a. auto-swoosh).
///
/// Spacestrator launches a project's apps onto a freshly-created desktop. With
/// this behavior enabled (the macOS default), activating an app that already has
/// a window on another desktop drags the whole session back to that desktop — so
/// the rest of the project lands on the wrong Space. On macOS with SIP enabled
/// there is no reliable private API to move windows back (SLSSetWindowListWorkspace
/// / SLSManagedDisplaySetCurrentSpace no-op on current releases), so the robust,
/// supported fix is to turn the behavior off, exactly as yabai/Hammerspoon users do.
enum SpaceSwitchPrefs {

    /// True when both flags are already set so apps stay on the active desktop.
    static var isDisabled: Bool {
        readBool(domain: "-g", key: "AppleSpacesSwitchOnActivate") == false
            && readBool(domain: "com.apple.dock", key: "workspaces-auto-swoosh") == false
    }

    /// Disable the auto-switch behavior and restart the Dock so it takes effect.
    /// Returns true if the `defaults` writes succeeded.
    @discardableResult
    static func disable() -> Bool {
        let ok1 = Shell.run("/usr/bin/defaults",
                            ["write", "-g", "AppleSpacesSwitchOnActivate", "-bool", "false"]).success
        let ok2 = Shell.run("/usr/bin/defaults",
                            ["write", "com.apple.dock", "workspaces-auto-swoosh", "-bool", "NO"]).success
        Shell.run("/usr/bin/killall", ["Dock"])
        return ok1 && ok2
    }

    private static func readBool(domain: String, key: String) -> Bool? {
        let result = Shell.run("/usr/bin/defaults", ["read", domain, key])
        guard result.success else { return nil }
        let v = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return v == "0" ? false : (v == "1" ? true : nil)
    }
}
