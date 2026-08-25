import AppKit
import SwiftUI

struct PopoverContentState: Equatable {
    enum Status: String {
        case loading
        case ready
        case error
    }

    var status: Status
    var profileId: String
    var profileName: String
    var originalText: String
    var enhancedText: String
    var error: String
    var job: SelectionJob = .enhance
    var translateLanguage: TranslateLanguage = .auto
}

@MainActor
final class PopoverModel: ObservableObject {
    @Published var state: PopoverContentState

    init(state: PopoverContentState) {
        self.state = state
    }
}

@MainActor
final class EnhancePopoverController {
    private var panel: NSPanel?
    private var session: AppSession?
    private weak var windows: AppWindows?
    private let model = PopoverModel(
        state: PopoverContentState(
            status: .loading,
            profileId: "grammar",
            profileName: "Grammar",
            originalText: "",
            enhancedText: "",
            error: ""
        )
    )

    func attach(session: AppSession, windows: AppWindows) {
        self.session = session
        self.windows = windows
    }

    func showDemo(near point: NSPoint) {
        let profile = session?.currentProfile
        show(
            state: PopoverContentState(
                status: .ready,
                profileId: profile?.id ?? "grammar",
                profileName: profile?.name ?? "Grammar",
                originalText: "lets meet tmrw morning if thats ok",
                enhancedText: "Let's meet tomorrow morning, if that works for you.",
                error: ""
            ),
            near: point
        )
    }

    func show(state: PopoverContentState, near point: NSPoint) {
        model.state = state
        let window = ensureWindow()
        let readyHeight: CGFloat = 240
        let height: CGFloat = state.status == .loading ? WindowMetrics.popoverDefault.height : min(
            WindowMetrics.popoverMax.height,
            max(WindowMetrics.popoverDefault.height, readyHeight)
        )
        WindowPresentation.show(
            window,
            policy: WindowPresentation.overlayPolicy,
            frame: Self.clampedFrame(anchor: point, size: CGSize(width: WindowMetrics.popoverDefault.width, height: height))
        )
    }

    var isVisible: Bool { panel?.isVisible == true }

    func hide() {
        panel?.orderOut(nil)
    }

    private func ensureWindow() -> NSPanel {
        if let panel { return panel }
        guard let session, let windows else {
            preconditionFailure("EnhancePopoverController.attach must run first")
        }
        let created = ProductWindowFactory.makeEnhancePopover(size: WindowMetrics.popoverDefault)
        created.contentViewController = GlassHostingController(
            rootView: PopoverView(
                model: model,
                onClose: { [weak windows] in windows?.hidePopover() },
                onReplace: { [weak windows] in windows?.coordinator.replace() },
                onCopy: { [weak windows] in windows?.coordinator.copyResult() },
                onRetry: { [weak windows] in windows?.coordinator.retry() },
                onSwitchProfile: { [weak windows] id in windows?.coordinator.switchProfile(id) },
                onSwitchLanguage: { [weak windows] language in windows?.coordinator.switchTranslateLanguage(language) }
            )
            .environmentObject(session)
            .environmentObject(windows),
            material: .hudWindow,
            cornerRadius: WindowMetrics.windowCorner,
            firstMouse: true
        )
        panel = created
        return created
    }

    static func clampedFrame(anchor: NSPoint, size: CGSize) -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main
        let work = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        let gap = WindowMetrics.popoverEdgeGap
        let width = min(max(size.width, WindowMetrics.popoverMin.width), work.width - gap * 2)
        let height = min(max(size.height, WindowMetrics.popoverMin.height), work.height - gap * 2)

        var x = anchor.x + WindowMetrics.popoverCursorOffset.x
        var y = anchor.y + WindowMetrics.popoverCursorOffset.y - height
        if y < work.minY + gap {
            y = anchor.y + 16
        }
        if x + width > work.maxX - gap {
            x = anchor.x - width - 12
        }
        x = min(max(x, work.minX + gap), work.maxX - width - gap)
        y = min(max(y, work.minY + gap), work.maxY - height - gap)
        return NSRect(x: x.rounded(), y: y.rounded(), width: width.rounded(), height: height.rounded())
    }
}
