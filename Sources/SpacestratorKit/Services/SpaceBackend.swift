import Foundation

/// Strategy interface for Mission Control space control. Two implementations ship:
///   • YabaiSpaceBackend   — shells out to yabai; robust, works with SIP enabled
///                            for create+focus. Preferred when yabai is installed.
///   • SkyLightSpaceBackend — calls private SkyLight APIs directly. No external
///                            dependency, but version-sensitive (esp. space creation).
protocol SpaceBackend {
    var name: String { get }

    /// Switch to the 1-based index among *user* desktops.
    func gotoSpace(index: Int)

    /// Create a new desktop, switch to it, then call completion(success).
    func gotoNewUserSpace(completion: @escaping (Bool) -> Void)
}
