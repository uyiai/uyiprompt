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

    func show(text: String, bundleID: String?, near point: NSPoint, selectionBounds: CGRect? = nil) {
        pendingText = text
        pendingBundleID = bundleID
        let window = ensureWindow()
        WindowPresentation.show(
            window,
            policy: WindowPresentation.overlayPolicy,
            frame: Self.clampedFrame(
                anchor: point,
                size: WindowMetrics.actionBarSize,
                selectionBounds: selectionBounds
            )
        )
        window.invalidateShadow()
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
            material: nil,
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

    static func clampedFrame(
        anchor: NSPoint,
        size: CGSize,
        selectionBounds: CGRect? = nil,
        workArea: CGRect? = nil
    ) -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) })
            ?? selectionBounds.flatMap { bounds in
                NSScreen.screens.first(where: { $0.frame.intersects(bounds) })
            }
            ?? NSScreen.main
        let work = workArea ?? screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        return ActionBarPlacement.frame(
            selectionBounds: selectionBounds,
            cursor: anchor,
            size: size,
            workArea: work
        )
    }
}

/// Sits under the selection so host Copy / Look Up chrome (usually above or beside the text) stays clickable.
enum ActionBarPlacement {
    static func frame(
        selectionBounds: CGRect?,
        cursor: NSPoint,
        size: CGSize,
        workArea: CGRect
    ) -> NSRect {
        let inset = WindowMetrics.actionBarScreenInset
        var work = workArea.insetBy(dx: inset, dy: inset)
        if work.width < size.width {
            work.origin.x = workArea.minX
            work.size.width = max(size.width, workArea.width)
        }
        if work.height < size.height {
            work.origin.y = workArea.minY
            work.size.height = max(size.height, workArea.height)
        }

        let selection = resolvedSelection(selectionBounds, cursor: cursor)
        let avoid = nativeChromeAvoidRect(around: selection)
        let xs = horizontalOrigins(cursor: cursor, selection: selection, size: size, work: work)
        let gap = WindowMetrics.actionBarGap
        let chrome = WindowMetrics.actionBarNativeChromeHeight

        var candidates: [NSRect] = []
        candidates.reserveCapacity(xs.count * 2)
        for x in xs {
            candidates.append(
                NSRect(x: x, y: selection.minY - gap - size.height, width: size.width, height: size.height)
            )
        }
        for x in xs {
            candidates.append(
                NSRect(x: x, y: selection.maxY + chrome + gap, width: size.width, height: size.height)
            )
        }

        for raw in candidates {
            let rect = clamp(raw, size: size, work: work)
            if !rect.intersects(avoid) {
                return rounded(rect)
            }
        }

        let fallback = candidates
            .map { clamp($0, size: size, work: work) }
            .min { intersectionArea($0, avoid) < intersectionArea($1, avoid) }
        return rounded(fallback ?? clamp(candidates[0], size: size, work: work))
    }

    static func nativeChromeAvoidRect(around selection: CGRect) -> CGRect {
        let pad: CGFloat = 8
        let chrome = WindowMetrics.actionBarNativeChromeHeight
        return CGRect(
            x: selection.minX - pad,
            y: selection.minY - pad,
            width: max(selection.width, 1) + pad * 2,
            height: max(selection.height, 1) + pad + chrome
        )
    }

    private static func resolvedSelection(_ bounds: CGRect?, cursor: NSPoint) -> CGRect {
        if let bounds, bounds.width >= 1, bounds.height >= 1 {
            return bounds
        }
        return CGRect(x: cursor.x, y: cursor.y, width: 1, height: 1)
    }

    private static func horizontalOrigins(
        cursor: NSPoint,
        selection: CGRect,
        size: CGSize,
        work: CGRect
    ) -> [CGFloat] {
        func clampX(_ x: CGFloat) -> CGFloat {
            min(max(x, work.minX), max(work.minX, work.maxX - size.width))
        }
        let xs = [
            clampX(cursor.x - size.width / 2),
            clampX(selection.maxX - size.width),
            clampX(selection.minX),
        ]
        var unique: [CGFloat] = []
        for x in xs {
            if unique.contains(where: { abs($0 - x) < 0.5 }) { continue }
            unique.append(x)
        }
        return unique
    }

    private static func clamp(_ rect: NSRect, size: CGSize, work: CGRect) -> NSRect {
        NSRect(
            x: min(max(rect.minX, work.minX), max(work.minX, work.maxX - size.width)),
            y: min(max(rect.minY, work.minY), max(work.minY, work.maxY - size.height)),
            width: size.width,
            height: size.height
        )
    }

    private static func intersectionArea(_ a: NSRect, _ b: NSRect) -> CGFloat {
        let overlap = a.intersection(b)
        guard !overlap.isNull, !overlap.isInfinite else { return 0 }
        return max(0, overlap.width) * max(0, overlap.height)
    }

    private static func rounded(_ rect: NSRect) -> NSRect {
        NSRect(
            x: rect.minX.rounded(),
            y: rect.minY.rounded(),
            width: rect.width.rounded(),
            height: rect.height.rounded()
        )
    }
}
