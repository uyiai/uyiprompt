import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var session: AppSession?
    private weak var windows: AppWindows?

    func attach(session: AppSession, windows: AppWindows) {
        self.session = session
        self.windows = windows
    }

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        let window = ensureWindow()
        ProductWindowFactory.present(window, size: window.frame.size.width < 200 ? WindowMetrics.onboardingPreferred : window.frame.size)
    }

    func focus() {
        if let window { ProductWindowFactory.present(window) }
    }

    func close() {
        window?.orderOut(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(origin: .zero, size: WindowMetrics.onboardingPreferred)
        let size = CGSize(
            width: min(screen.width, max(WindowMetrics.onboardingMin.width, WindowMetrics.onboardingPreferred.width)),
            height: min(screen.height, max(WindowMetrics.onboardingMin.height, WindowMetrics.onboardingPreferred.height))
        )
        let created = ProductWindowFactory.makeOnboardingWindow(size: size)
        created.setContentSize(size)
        created.center()
        created.delegate = self
        if let session, let windows {
            let hosting = NSHostingController(
                rootView: OnboardingView()
                    .environmentObject(session)
                    .environmentObject(windows)
            )
            hosting.sizingOptions = []
            created.contentViewController = hosting
        }
        created.setContentSize(size)
        window = created
        return created
    }

    func windowWillClose(_ notification: Notification) {
        windows?.completeOnboarding()
    }
}
