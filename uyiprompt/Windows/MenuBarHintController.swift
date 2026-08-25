import AppKit
import SwiftUI

/// Short toast under the status item so first-run does not vanish into the tray.
@MainActor
final class MenuBarHintController {
    private var window: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(from button: NSStatusBarButton) {
        hide()
        let size = CGSize(width: 320, height: 72)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.contentViewController = GlassHostingController(
            rootView: MenuBarHintView(),
            cornerRadius: 12
        )

        let buttonRect = Self.screenFrame(of: button)
        var x = buttonRect.midX - size.width / 2
        var y = buttonRect.minY - size.height - 10
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(buttonRect.origin) }) ?? NSScreen.main {
            let work = screen.visibleFrame
            x = min(max(x, work.minX + 8), work.maxX - size.width - 8)
            y = min(max(y, work.minY + 8), work.maxY - size.height - 8)
        }
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        window = panel

        button.highlight(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            button.highlight(false)
        }

        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.hide() }
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        window?.orderOut(nil)
        window = nil
    }

    private static func screenFrame(of button: NSStatusBarButton) -> NSRect {
        guard let window = button.window else { return .zero }
        let local = button.convert(button.bounds, to: nil)
        return window.convertToScreen(local)
    }
}
