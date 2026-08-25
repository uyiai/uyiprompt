import AppKit
import Carbon.HIToolbox
import CoreGraphics

enum KeystrokeSynthesizer {
    static func commandKey(_ keyCode: CGKeyCode) {
        post(keyCode, flags: .maskCommand)
    }

    static func commandC() {
        commandKey(CGKeyCode(kVK_ANSI_C))
    }

    static func commandV() {
        commandKey(CGKeyCode(kVK_ANSI_V))
    }

    static var blockingModifiersDown: Bool {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        return flags.contains(.maskShift)
            || flags.contains(.maskAlternate)
            || flags.contains(.maskControl)
    }

    private static func post(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }
}
