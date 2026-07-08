import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

/// Centralises the TCC permission prompts the app depends on:
///   • Accessibility   — driving JetBrains/Android Studio dialogs (AppleScript UI scripting)
///   • Screen Recording — reading window titles across spaces for the snapshot
///   • Automation       — Apple Events to System Events / Chrome / Finder (declared via Info.plist)
enum Permissions {

    /// Prompts for Accessibility if not yet trusted. Returns the current trust state.
    @discardableResult
    static func ensureAccessibility(prompt: Bool = true) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Screen Recording is needed to read other apps' window titles (kCGWindowName)
    /// on modern macOS. Without it the snapshot still lists apps but titles come back empty.
    @discardableResult
    static func ensureScreenRecording(prompt: Bool = true) -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        if prompt { return CGRequestScreenCaptureAccess() }
        return false
    }

    static func openAccessibilitySettings() {
        openSettings("Privacy_Accessibility")
    }

    static func openScreenRecordingSettings() {
        openSettings("Privacy_ScreenCapture")
    }

    private static func openSettings(_ anchor: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
        NSWorkspace.shared.open(url)
    }
}
