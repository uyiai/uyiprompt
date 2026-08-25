import AppKit

/// Presentation policy for product windows.
/// Overlays (action chips, rewrite/translate results) must not activate the app.
/// Settings, onboarding, and the draft panel take key.
enum WindowPresentation {
    enum Policy: Equatable, Sendable {
        case inactive
        case key
    }

    struct Plan: Equatable, Sendable {
        var activateApp: Bool
        var makeKey: Bool
        var orderFrontRegardless: Bool
    }

    static let overlayPolicy: Policy = .inactive
    static let productWindowPolicy: Policy = .key

    static func plan(for policy: Policy) -> Plan {
        switch policy {
        case .inactive:
            return Plan(activateApp: false, makeKey: false, orderFrontRegardless: true)
        case .key:
            return Plan(activateApp: true, makeKey: true, orderFrontRegardless: true)
        }
    }

    static func isNonactivatingOverlay(_ window: NSWindow) -> Bool {
        window.styleMask.contains(.nonactivatingPanel)
    }

    @MainActor
    static func show(_ window: NSWindow, policy: Policy, frame: NSRect? = nil) {
        let plan = plan(for: policy)
        if let frame {
            window.setFrame(frame, display: true)
        }
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        if plan.orderFrontRegardless {
            window.orderFrontRegardless()
        }
        if plan.activateApp {
            NSApp.activate()
        }
        if plan.makeKey {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
