import Foundation

/// Auto-dismisses the JetBrains / Android Studio "Open Project" dialog that pops up
/// when opening a folder in an already-running IDE. Ports services/jetbrainsOpenProject.lua,
/// but runs AppleScript in-process via NSAppleScript instead of writing temp .applescript files.
///
/// Requires Accessibility + Automation (System Events) permission.
enum JetBrainsOpenProject {

    /// Schedule both keyboard and click dismissal attempts at staggered delays,
    /// matching the original timing arrays.
    static func schedule(processName: String, choice: DialogChoice, customButtonLabel: String?) {
        guard choice != .off else { return }

        let isNewWindow = (choice == .newWindow)
        let label: String = {
            if let l = customButtonLabel, !l.isEmpty { return l }
            return choice == .thisWindow ? "This Window" : "New Window"
        }()

        // Keyboard approach first (faster), then click-based fallback.
        for delay in [0.8, 1.5, 2.3, 3.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                runKeyboardDismissal(processName: processName, isNewWindow: isNewWindow)
            }
        }
        for delay in [4.0, 5.2, 6.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                runClickDismissal(processName: processName, buttonLabel: label)
            }
        }
    }

    private static func runKeyboardDismissal(processName: String, isNewWindow: Bool) {
        let p = escape(processName)
        let nav = isNewWindow
            ? "    key code 48 -- Tab to move focus\n    delay 0.1\n    key code 49 -- Space to activate button"
            : "    -- use This Window (default focus)"
        let script = """
        tell application "System Events"
          if not (exists process "\(p)") then return "noapp"
          tell process "\(p)"
            set frontmost to true
            delay 0.2
        \(nav)
          end tell
        end tell
        return "ok"
        """
        execute(script)
    }

    private static func runClickDismissal(processName: String, buttonLabel: String) {
        let p = escape(processName)
        let b = escape(buttonLabel)
        let script = """
        tell application "System Events"
          if not (exists process "\(p)") then return "noapp"
          tell process "\(p)"
            set frontmost to true
            delay 0.2
            repeat with w in windows
              try
                set wt to title of w as string
                if wt contains "Open" or wt contains "Project" then
                  try
                    repeat with btn in (buttons of sheet 1 of w)
                      if (name of btn as string) contains "\(b)" then
                        click btn
                        return "ok"
                      end if
                    end repeat
                  end try
                  try
                    repeat with btn in (buttons of w)
                      if (name of btn as string) contains "\(b)" then
                        click btn
                        return "ok"
                      end if
                    end repeat
                  end try
                end if
              end try
            end repeat
          end tell
        end tell
        return "miss"
        """
        execute(script)
    }

    private static func execute(_ source: String) {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return }
        script.executeAndReturnError(&error)
        if let error {
            Log.error("AppleScript dismissal: \(error)")
        }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
