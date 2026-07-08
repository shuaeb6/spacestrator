import Foundation

/// Drives Mission Control spaces through the `yabai` CLI. Both `space --create`
/// and `space --focus` work with SIP enabled (only window-moving needs SIP off,
/// which this app never does).
final class YabaiSpaceBackend: SpaceBackend {
    let name = "yabai"
    private let binary: String

    init?(binaryPath: String? = Shell.which("yabai")) {
        guard let binaryPath else { return nil }
        self.binary = binaryPath
    }

    func gotoSpace(index: Int) {
        Shell.run(binary, ["-m", "space", "--focus", String(index)])
    }

    func gotoNewUserSpace(completion: @escaping (Bool) -> Void) {
        let created = Shell.run(binary, ["-m", "space", "--create"]).success
        guard created else {
            completion(false)
            return
        }
        // The new space is appended on the active display; focus the last one.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let focused = Shell.run(self.binary, ["-m", "space", "--focus", "last"]).success
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(focused)
            }
        }
    }
}
