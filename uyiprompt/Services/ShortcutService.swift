import AppKit
import Carbon.HIToolbox

/// Global hotkeys must be registered with Carbon `RegisterEventHotKey`.
/// SwiftUI `.keyboardShortcut` only fires while this app is the key window.
///
/// The C callback hops to the main queue; it must not assume it is already
/// isolated to `MainActor`.
final class ShortcutService: @unchecked Sendable {
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    private weak var windows: AppWindows?

    @MainActor
    func install(windows: AppWindows) {
        self.windows = windows
        register(keyCode: UInt32(kVK_ANSI_U), modifiers: UInt32(cmdKey + shiftKey), actionID: 1)
        register(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(controlKey + shiftKey), actionID: 2)
        register(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey + shiftKey), actionID: 3)
        register(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey + shiftKey), actionID: 4)
        register(keyCode: UInt32(kVK_ANSI_O), modifiers: UInt32(controlKey + shiftKey), actionID: 5)
        installHandler()
    }

    func invalidate() {
        for hotKey in hotKeys {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func register(keyCode: UInt32, modifiers: UInt32, actionID: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID(signature: OSType(0x55594950), id: actionID)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr, let hotKeyRef {
            hotKeys.append(hotKeyRef)
        } else {
            Log.hotkeys.error("hotkey \(actionID) registration failed (status \(status)) — likely taken by another app")
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userInfo in
                guard let userInfo else { return noErr }
                let service = Unmanaged<ShortcutService>.fromOpaque(userInfo).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let identifier = hotKeyID.id
                DispatchQueue.main.async {
                    service.handle(id: identifier)
                }
                return noErr
            },
            1,
            &eventType,
            userInfo,
            &eventHandler
        )
    }

    @MainActor
    private func handle(id: UInt32) {
        switch id {
        case 1: windows?.togglePanel()
        case 2: windows?.enhanceSelection()
        case 3: windows?.translateSelection()
        case 4: windows?.enhancePaletteSelection()
        case 5: windows?.captureTextFromScreen()
        default: break
        }
    }
}
