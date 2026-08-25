import AppKit

/// Watches mouse-up after a selection gesture and shows the action bar.
@MainActor
final class SelectionWatcher {
    private var session: AppSession?
    private weak var windows: AppWindows?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var activateObserver: NSObjectProtocol?
    private var mouseDownPoint: NSPoint?
    private var mouseDownText = ""
    private var dragged = false
    private var pending: Task<Void, Never>?
    private var ignoreScrollUntil = Date.distantPast

    private static let ignoredBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.apple.SecurityAgent",
        "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty",
        "com.github.wez.wezterm",
        "org.alacritty",
        "dev.warp.Warp-Stable",
        "com.apple.loginwindow",
    ]

    func attach(session: AppSession, windows: AppWindows) {
        invalidate()
        self.session = session
        self.windows = windows
        install()
    }

    func invalidate() {
        pending?.cancel()
        pending = nil
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let activateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activateObserver)
            self.activateObserver = nil
        }
    }

    private func install() {
        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseDown, .otherMouseDown,
        ]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let payload = EventPayload(event)
            Task { @MainActor in
                self?.handle(payload, fromOurApp: true)
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let payload = EventPayload(event)
            Task { @MainActor in
                self?.handle(payload, fromOurApp: false)
            }
        }
        activateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in
                guard let self else { return }
                if let id, SelectionService.isOwnApp(id) { return }
                if Date() < self.ignoreScrollUntil { return }
                self.windows?.hideActionBar()
            }
        }
        NSLog("[uyiprompt] selection watcher installed")
    }

    private struct EventPayload: Sendable {
        var type: NSEvent.EventType
        var clickCount: Int
        var location: NSPoint
        var windowNumber: Int

        init(_ event: NSEvent) {
            type = event.type
            clickCount = event.clickCount
            location = NSEvent.mouseLocation
            windowNumber = event.windowNumber
        }
    }

    private func handle(_ event: EventPayload, fromOurApp: Bool) {
        if fromOurApp, let window = NSApp.window(withWindowNumber: event.windowNumber),
           windows?.isActionBarWindow(window) == true {
            return
        }

        switch event.type {
        case .leftMouseDown:
            windows?.hideActionBar()
            mouseDownPoint = event.location
            mouseDownText = SelectionService.axSelectedText() ?? ""
            dragged = false
            pending?.cancel()
        case .leftMouseDragged:
            if let start = mouseDownPoint {
                if hypot(event.location.x - start.x, event.location.y - start.y) >= 4 {
                    dragged = true
                }
            }
        case .leftMouseUp:
            let point = event.location
            let down = mouseDownPoint ?? point
            let distance = hypot(point.x - down.x, point.y - down.y)
            let clickCount = event.clickCount
            let wasDragged = dragged || distance >= 6
            pending?.cancel()
            pending = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 160_000_000)
                guard !Task.isCancelled else { return }
                await self?.evaluate(
                    at: point,
                    dragDistance: distance,
                    clickCount: clickCount,
                    dragged: wasDragged
                )
            }
        case .rightMouseDown, .otherMouseDown:
            windows?.hideActionBar()
            pending?.cancel()
        default:
            break
        }
    }

    private func evaluate(at point: NSPoint, dragDistance: CGFloat, clickCount: Int, dragged: Bool) async {
        guard let session, let windows else { return }
        guard session.selectionActionBarEnabled else { return }
        guard session.onboardingCompleted else { return }
        guard SelectionService.isTrusted else { return }
        if windows.isOnboardingVisible { return }
        if windows.isResultPopoverVisible { return }

        SelectionService.enableEnhancedAccessibility()
        var snap = SelectionService.axSelectionSnapshot()
        var text = snap.text.trimmingCharacters(in: .whitespacesAndNewlines)

        let allowClipboard = dragged || clickCount >= 2
        if text.count < 2, allowClipboard {
            if let copied = await SelectionService.peekClipboardSelection() {
                text = copied.trimmingCharacters(in: .whitespacesAndNewlines)
                snap.text = text
            }
        }

        if snap.isSecure || snap.isIgnorableRole {
            windows.hideActionBar()
            return
        }
        if SelectionService.isOwnApp(snap.bundleID) {
            windows.hideActionBar()
            return
        }
        if let id = snap.bundleID, Self.ignoredBundleIDs.contains(id) {
            windows.hideActionBar()
            return
        }

        guard text.count >= 2 else {
            windows.hideActionBar()
            return
        }

        let changed = text != mouseDownText.trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = dragged || dragDistance >= 6 || clickCount >= 2 || changed
        guard selected else {
            windows.hideActionBar()
            return
        }

        var selectionBounds: CGRect?
        if let bounds = snap.cocoaBounds, ProductWindowFactory.frameIntersectsAnyScreen(bounds) {
            selectionBounds = bounds
        }

        ignoreScrollUntil = Date().addingTimeInterval(0.8)
        windows.showActionBar(
            text: text,
            bundleID: snap.bundleID,
            near: point,
            selectionBounds: selectionBounds
        )
    }
}
