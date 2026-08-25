import AppKit
import SwiftUI

/// Puts SwiftUI on top of `NSVisualEffectView` so the desktop behind the window
/// actually blurs. CSS/`backdrop-filter` cannot do this; Electron wrapped the
/// same AppKit view.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override var isOpaque: Bool { false }

    required init(rootView: Content) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
final class GlassHostingController<Content: View>: NSViewController {
    private let rootView: Content
    private let material: NSVisualEffectView.Material?
    private let blending: NSVisualEffectView.BlendingMode
    private let emphasized: Bool
    private let cornerRadius: CGFloat
    private let firstMouse: Bool

    init(
        rootView: Content,
        material: NSVisualEffectView.Material? = .hudWindow,
        blending: NSVisualEffectView.BlendingMode = .withinWindow,
        emphasized: Bool = true,
        cornerRadius: CGFloat = 0,
        firstMouse: Bool = false
    ) {
        self.rootView = rootView
        self.material = material
        self.blending = blending
        self.emphasized = emphasized
        self.cornerRadius = cornerRadius
        self.firstMouse = firstMouse
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container: NSView
        if let material {
            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = material
            visualEffectView.blendingMode = blending
            visualEffectView.state = emphasized ? .active : .followsWindowActiveState
            visualEffectView.isEmphasized = emphasized
            container = visualEffectView
        } else {
            let plain = NSView()
            plain.wantsLayer = true
            plain.layer?.isOpaque = false
            plain.layer?.backgroundColor = NSColor.clear.cgColor
            container = plain
        }
        if cornerRadius > 0 {
            container.wantsLayer = true
            container.layer?.cornerRadius = cornerRadius
            container.layer?.cornerCurve = .continuous
            container.layer?.masksToBounds = true
        }
        let hosted: NSHostingView<Content> = firstMouse
            ? FirstMouseHostingView(rootView: rootView)
            : NSHostingView(rootView: rootView)
        hosted.sizingOptions = []
        hosted.translatesAutoresizingMaskIntoConstraints = false
        if firstMouse == false {
            hosted.wantsLayer = true
            hosted.layer?.isOpaque = false
            hosted.layer?.backgroundColor = NSColor.clear.cgColor
        }
        container.addSubview(hosted)
        NSLayoutConstraint.activate([
            hosted.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosted.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosted.topAnchor.constraint(equalTo: container.topAnchor),
            hosted.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container
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
        panel.title = "uyiprompt"
        panel.identifier = NSUserInterfaceItemIdentifier("uyiprompt.panel")
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.minSize = WindowMetrics.panelMinSize
        panel.orderOut(nil)
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
        panel.identifier = NSUserInterfaceItemIdentifier("uyiprompt.popover")
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

    /// PopClip-style chip bar. Never activates, so the source selection stays.
    static func makeActionBar(size: CGSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier("uyiprompt.actionbar")
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        panel.orderOut(nil)
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
        window.title = L10n.t("window.settings")
        window.identifier = NSUserInterfaceItemIdentifier("uyiprompt.settings")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = CGSize(width: 760, height: 500)
        window.toolbarStyle = .unified
        window.level = .floating
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92)
        disableMaximize(window)
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
        window.title = L10n.t("window.welcome")
        window.identifier = NSUserInterfaceItemIdentifier("uyiprompt.onboarding")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isOpaque = true
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.level = .floating
        disableMaximize(window)
        return window
    }

    /// Superwhisper-style: close and minimize only. No zoom / full screen.
    static func disableMaximize(_ window: NSWindow) {
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }

    private static func configureGlass(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.78)
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
    }

    static func screenForPlacement(near point: NSPoint? = nil) -> NSScreen {
        if let point, let matched = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            return matched
        }
        if let statusScreen = NSApp.windows.first(where: { $0.className.contains("StatusBar") })?.screen {
            return statusScreen
        }
        if let builtIn = NSScreen.screens.first(where: { $0.frame.minX == 0 && $0.frame.minY == 0 }) {
            return builtIn
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    static func visibleFrame(on screen: NSScreen? = nil) -> NSRect {
        (screen ?? screenForPlacement()).visibleFrame
    }

    static func clampedFrame(_ size: CGSize, on screen: NSScreen? = nil) -> NSRect {
        let work = visibleFrame(on: screen)
        let width = min(max(size.width, 360), max(360, work.width - 24))
        let height = min(max(size.height, 240), max(240, work.height - 24))
        let x = work.midX - width / 2
        let y = work.midY - height / 2
        return NSRect(
            x: min(max(x, work.minX + 12), work.maxX - width - 12),
            y: min(max(y, work.minY + 12), work.maxY - height - 12),
            width: width,
            height: height
        )
    }

    static func centerOnMainScreen(_ window: NSWindow, size: CGSize? = nil) {
        window.setFrame(clampedFrame(size ?? window.frame.size), display: true)
    }

    static func frameIntersectsAnyScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame.insetBy(dx: 8, dy: 8)) }
    }

    static func present(_ window: NSWindow, size: CGSize? = nil, on screen: NSScreen? = nil) {
        WindowPresentation.show(
            window,
            policy: .key,
            frame: clampedFrame(size ?? window.frame.size, on: screen)
        )
    }
}
