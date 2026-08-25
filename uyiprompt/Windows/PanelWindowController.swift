import AppKit
import SwiftUI

@MainActor
final class PanelWindowController {
    private var panel: NSPanel?
    private var session: AppSession?
    private weak var windows: AppWindows?
    private var placed = false

    func attach(session: AppSession, windows: AppWindows) {
        self.session = session
        self.windows = windows
    }

    var isVisible: Bool { panel?.isVisible == true }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        let window = ensureWindow()
        window.setPinnedBehavior(session?.panelPinned ?? true)
        ProductWindowFactory.present(window, size: WindowMetrics.panelSize)
        window.setPinnedBehavior(session?.panelPinned ?? true)
        placed = true
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func setPinned(_ pinned: Bool) {
        panel?.level = pinned ? .statusBar : .normal
    }

    private func ensureWindow() -> NSPanel {
        if let panel { return panel }
        let created = ProductWindowFactory.makeUtilityPanel(size: WindowMetrics.panelSize)
        guard let session, let windows else {
            preconditionFailure("PanelWindowController.attach must run first")
        }
        let root = PanelView()
            .environmentObject(session)
            .environmentObject(windows)
        created.contentViewController = GlassHostingController(
            rootView: root,
            material: .hudWindow,
            cornerRadius: WindowMetrics.windowCorner
        )
        created.setPinnedBehavior(session.panelPinned)
        panel = created
        return created
    }
}

private extension NSPanel {
    func setPinnedBehavior(_ pinned: Bool) {
        level = pinned ? .statusBar : .normal
    }
}
