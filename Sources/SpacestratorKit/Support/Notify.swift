import Foundation
import UserNotifications
import AppKit

/// Replacement for `hs.notify.new({...}):send()`.
/// Uses UserNotifications when the app is signed/bundled; falls back to a logged
/// line during unsigned development runs where UNUserNotificationCenter is unavailable.
enum Notify {
    private static var authorized = false
    private static var requested = false

    static func bootstrap() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        requested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            authorized = granted
        }
    }

    static func send(title: String, body: String) {
        Log.info("\(title) — \(body)")
        guard requested, Bundle.main.bundleIdentifier != nil else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { Log.error("notify failed: \(error.localizedDescription)") }
        }
    }
}
