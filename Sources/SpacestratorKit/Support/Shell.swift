import Foundation

/// Replacement for `hs.execute`. Runs a binary directly (no shell), captures
/// stdout, and reports success via the process exit status — matching the
/// `_, status = hs.execute(cmd)` pattern from the Lua code where `status`
/// was the boolean success flag.
enum Shell {
    @discardableResult
    static func run(_ launchPath: String, _ args: [String]) -> (output: String, success: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            Log.error("Failed to launch \(launchPath): \(error.localizedDescription)")
            return ("", false)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (output, process.terminationStatus == 0)
    }

    /// `/usr/bin/open` with the given arguments.
    @discardableResult
    static func open(_ args: [String]) -> Bool {
        run("/usr/bin/open", args).success
    }

    /// Whether an executable is resolvable on PATH (used to detect yabai).
    static func which(_ binary: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(binary)",   // Apple Silicon Homebrew
            "/usr/local/bin/\(binary)",      // Intel Homebrew
            "/usr/bin/\(binary)"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        let result = run("/usr/bin/which", [binary])
        let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return (result.success && !trimmed.isEmpty) ? trimmed : nil
    }
}
