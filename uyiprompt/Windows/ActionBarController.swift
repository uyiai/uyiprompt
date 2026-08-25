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
        let size = WindowMetrics.actionBarSize
        let frame = Self.clampedFrame(anchor: point, size: size)
        window.setFrame(frame, display: true)
        window.alphaValue = 1
        window.orderFrontRegardless()
        NSLog("[uyiprompt] action bar show frame=%@ textLen=%ld", NSStringFromRect(frame), text.count)
    }

    func hide() {
        panel?.orderOut(nil)
        pendingText = ""
        pendingBundleID = nil
    }

    private func ensureWindow() -> NSPanel {
        if let panel { return panel }
        guard windows != nil else {
            preconditionFailure("ActionBarController.attach must run first")
        }
        let created = ProductWindowFactory.makeActionBar(size: WindowMetrics.actionBarSize)
        let root = ActionBarView(
            onEnhance: { [weak self] in self?.run(.enhance) },
            onTranslate: { [weak self] in self?.run(.translate) }
        )
        let host = FirstMouseHostingView(rootView: root)
        host.sizingOptions = []
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = WindowMetrics.actionBarSize.height / 2
        effect.layer?.masksToBounds = true
        host.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            host.topAnchor.constraint(equalTo: effect.topAnchor),
            host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        effect.frame = NSRect(origin: .zero, size: WindowMetrics.actionBarSize)
        host.frame = effect.bounds
        created.contentView = effect
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

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
}
