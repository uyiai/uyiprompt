import AppKit
import SwiftUI

/// Tiny non-activating chip bar, PopClip-style. Must not steal the source selection.
@MainActor
final class ActionBarController {
    private var panel: NSPanel?
    private var session: AppSession?
    private weak var windows: AppWindows?
    private var pendingText = ""
    private var pendingBundleID: String?

    var isVisible: Bool { panel?.isVisible == true }

    func attach(session: AppSession, windows: AppWindows) {
        self.session = session
        self.windows = windows
    }

    func isBarWindow(_ window: NSWindow?) -> Bool {
        guard let window, let panel else { return false }
        return window === panel
    }

    func show(text: String, bundleID: String?, near point: NSPoint) {
        pendingText = text
        pendingBundleID = bundleID
        let window = ensureWindow()
        WindowPresentation.show(
            window,
            policy: WindowPresentation.overlayPolicy,
            frame: Self.clampedFrame(anchor: point, size: WindowMetrics.actionBarSize)
        )
    }

    func hide() {
        panel?.orderOut(nil)
        pendingText = ""
        pendingBundleID = nil
    }

    private func ensureWindow() -> NSPanel {
        if let panel { return panel }
        guard let session, windows != nil else {
            preconditionFailure("ActionBarController.attach must run first")
        }
        let created = ProductWindowFactory.makeActionBar(size: WindowMetrics.actionBarSize)
        created.contentViewController = GlassHostingController(
            rootView: ActionBarView(
                onEnhance: { [weak self] in self?.run(.enhance) },
                onTranslate: { [weak self] in self?.run(.translate) }
            )
            .environmentObject(session),
            material: .popover,
            blending: .behindWindow,
            cornerRadius: WindowMetrics.actionBarSize.height / 2,
            firstMouse: true
        )
        created.setContentSize(WindowMetrics.actionBarSize)
        panel = created
        return created
    }

    private func run(_ job: SelectionJob) {
        let text = pendingText
        let bundleID = pendingBundleID
        let anchor = panel.map { NSPoint(x: $0.frame.midX, y: $0.frame.minY) } ?? NSEvent.mouseLocation
        hide()
        windows?.runCapturedSelection(text: text, bundleID: bundleID, job: job, near: anchor)
    }

    static func clampedFrame(anchor: NSPoint, size: CGSize) -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main
        let work = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        var x = anchor.x + 10
        var y = anchor.y - size.height / 2
        if x + size.width > work.maxX - 8 {
            x = anchor.x - size.width - 10
        }
        x = min(max(x, work.minX + 8), work.maxX - size.width - 8)
        y = min(max(y, work.minY + 8), work.maxY - size.height - 8)
        return NSRect(x: x.rounded(), y: y.rounded(), width: size.width.rounded(), height: size.height.rounded())
    }
}
