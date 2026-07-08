import Foundation
import Carbon.HIToolbox
import AppKit

/// Replacement for `hs.hotkey.bind`. Registers system-wide hotkeys via Carbon's
/// RegisterEventHotKey, which (unlike a CGEvent tap) does not itself require
/// Accessibility permission.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {
        installHandlerIfNeeded()
    }

    /// `keyCode` is a Carbon virtual key code (e.g. kVK_ANSI_P).
    /// `modifiers` is a Carbon modifier mask (cmdKey | optionKey | controlKey | shiftKey).
    @discardableResult
    func bind(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        let id = nextID
        nextID += 1

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x57534F52 /* 'WSOR' */), id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            Log.error("RegisterEventHotKey failed (status \(status))")
            return false
        }
        handlers[id] = handler
        return true
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData -> OSStatus in
            guard let eventRef, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            if let handler = center.handlers[hkID.id] {
                DispatchQueue.main.async { handler() }
            }
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)
    }
}
