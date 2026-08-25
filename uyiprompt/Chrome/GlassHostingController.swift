import AppKit
import SwiftUI

/// Puts SwiftUI on top of `NSVisualEffectView` so the desktop behind the window
/// actually blurs. CSS/`backdrop-filter` cannot do this; Electron wrapped the
/// same AppKit view.
@MainActor
final class GlassHostingController<Content: View>: NSViewController {
    private let visualEffectView = NSVisualEffectView()
    private let hostingController: NSHostingController<Content>

    init(
        rootView: Content,
        material: NSVisualEffectView.Material = .underWindowBackground,
        emphasized: Bool = true,
        cornerRadius: CGFloat = 0
    ) {
        hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = []
        super.init(nibName: nil, bundle: nil)
        visualEffectView.material = material
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = emphasized ? .active : .followsWindowActiveState
        visualEffectView.isEmphasized = emphasized
        if cornerRadius > 0 {
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = cornerRadius
            visualEffectView.layer?.masksToBounds = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = visualEffectView
        addChild(hostingController)
        let hosted = hostingController.view
        hosted.translatesAutoresizingMaskIntoConstraints = false
        hosted.wantsLayer = true
        hosted.layer?.backgroundColor = NSColor.clear.cgColor
        visualEffectView.addSubview(hosted)
        NSLayoutConstraint.activate([
            hosted.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hosted.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hosted.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hosted.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])
    }
}

@MainActor
enum ProductWindowFactory {
    /// Frameless always-on-top glass panel (scratchpad).
    static func makeUtilityPanel(size: CGSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        configureGlass(panel)
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.minSize = WindowMetrics.panelMinSize
        return panel
    }

    /// Non-activating overlay that must not steal the editor's selection.
    static func makeEnhancePopover(size: CGSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configureGlass(panel)
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        return panel
    }

    /// Custom Settings chrome: hidden titlebar over under-window material.
    static func makeSettingsWindow(size: CGSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configureGlass(window)
        window.title = "设置"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = CGSize(width: 900, height: 620)
        window.toolbarStyle = .unified
        return window
    }

    /// First-run is opaque, matching the Electron onboarding window.
    static func makeOnboardingWindow(size: CGSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isOpaque = true
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        return window
    }

    private static func configureGlass(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
    }

    static func centerOnMainScreen(_ window: NSWindow, size: CGSize? = nil) {
        let target = size ?? window.frame.size
        let width = max(target.width, 360)
        let height = max(target.height, 240)
        let work = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 80, y: 80, width: 1200, height: 800)
        let x = work.midX - width / 2
        let y = work.midY - height / 2
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    static func present(_ window: NSWindow, size: CGSize? = nil) {
        centerOnMainScreen(window, size: size)
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        NSApp.activate()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        let line = "[uyiprompt] present frame=\(NSStringFromRect(window.frame)) visible=\(window.isVisible) vc=\(String(describing: window.contentViewController))"
        NSLog("%@", line)
        if let data = (line + "\n").data(using: .utf8) {
            let url = URL(fileURLWithPath: "/tmp/uyiprompt-debug.log")
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
}
