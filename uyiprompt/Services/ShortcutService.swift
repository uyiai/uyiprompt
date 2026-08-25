import AppKit
import Carbon.HIToolbox

/// Global hotkeys must be registered with Carbon `RegisterEventHotKey`.
/// SwiftUI `.keyboardShortcut` only fires while this app is the key window.
///
/// The C callback hops to the main queue; it must not assume it is already
/// isolated to `MainActor`.
final class ShortcutService: @unchecked Sendable {
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef?] = []
    private weak var windows: AppWindows?

    @MainActor
    func install(windows: AppWindows) {
        self.windows = windows
        register(keyCode: UInt32(kVK_ANSI_U), actionID: 1)
        installHandler()
    }

    func invalidate() {
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        hotKeys.removeAll()
    }

    private func register(keyCode: UInt32, actionID: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID(signature: OSType(0x55594950), id: actionID)
        RegisterEventHotKey(keyCode, UInt32(cmdKey + shiftKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        hotKeys.append(hotKeyRef)
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
        default: break
        }
    }
}
