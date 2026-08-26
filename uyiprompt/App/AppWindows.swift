import AppKit
import SwiftUI

/// Single place that product UI asks when it needs a window shown or hidden.
@MainActor
final class AppWindows: ObservableObject {
    private(set) var session: AppSession!
    private let panel = PanelWindowController()
    private let popover = EnhancePopoverController()
    private let settings = SettingsWindowController()
    private let onboarding = OnboardingWindowController()
    private let actionBar = ActionBarController()
    private let selectionWatcher = SelectionWatcher()
    let coordinator = EnhanceCoordinator()
    weak var statusItem: StatusItemController?
    @Published private(set) var panelSeed: PanelSeed?

    struct PanelSeed: Equatable {
        var text: String
        var job: SelectionJob
    }

    var isOnboardingVisible: Bool { onboarding.isVisible }

    func attach(session: AppSession) {
        self.session = session
        panel.attach(session: session, windows: self)
        popover.attach(session: session, windows: self)
        settings.attach(session: session, windows: self)
        onboarding.attach(session: session, windows: self)
        actionBar.attach(session: session, windows: self)
        selectionWatcher.attach(session: session, windows: self)
        coordinator.attach(session: session, windows: self)
        applyAppearance()
    }

    var isResultPopoverVisible: Bool { popover.isVisible }

    func isActionBarWindow(_ window: NSWindow?) -> Bool {
        actionBar.isBarWindow(window)
    }

    func showActionBar(text: String, bundleID: String?, near point: NSPoint, selectionBounds: CGRect? = nil) {
        if isOnboardingVisible { return }
        actionBar.show(text: text, bundleID: bundleID, near: point, selectionBounds: selectionBounds)
    }

    func hideActionBar() {
        actionBar.hide()
    }

    func runCapturedSelection(text: String, bundleID: String?, job: SelectionJob, near point: NSPoint) {
        hideActionBar()
        coordinator.runCaptured(text: text, bundleID: bundleID, job: job, near: point)
    }

    func rewriteDraft(
        _ text: String,
        job: SelectionJob,
        onDelta: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        try await RewritePipeline.transform(message: text, job: job, session: session, onDelta: onDelta)
    }

    func invalidateSelectionWatcher() {
        selectionWatcher.invalidate()
    }

    func togglePanel() {
        if onboarding.isVisible {
            onboarding.focus()
            return
        }
        panel.toggle()
    }

    func showPanel(draft: String? = nil, job: SelectionJob? = nil) {
        if onboarding.isVisible {
            onboarding.focus()
            return
        }
        if let draft {
            seedPanel(draft: draft, job: job ?? .enhance)
        }
        hidePopover()
        hideActionBar()
        panel.show()
    }

    @discardableResult
    func seedPanel(draft: String, job: SelectionJob) -> PanelSeed? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let seed = PanelSeed(text: trimmed, job: job)
        panelSeed = seed
        return seed
    }

    func consumePanelSeed() {
        panelSeed = nil
    }

    func hidePanel() {
        panel.hide()
    }

    func enhanceSelection() {
        coordinator.enhanceSelection()
    }

    func translateSelection() {
        coordinator.translateSelection()
    }

    func enhancePaletteSelection() {
        coordinator.enhancePalette()
    }

    /// Screenshot → Vision OCR → draft panel, ready to translate or rewrite.
    func captureTextFromScreen() {
        if isOnboardingVisible {
            onboarding.focus()
            return
        }
        hidePopover()
        hideActionBar()
        Task { [weak self] in
            do {
                let text = try await OCRService.captureText()
                self?.showPanel(draft: text, job: .translate)
            } catch OCRService.OCRError.captureCancelled {
                return
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self?.showPopover(
                    state: .error(message, profile: L10n.t("menu.ocr"), job: .translate, recovery: .emptySelection),
                    near: NSEvent.mouseLocation
                )
            }
        }
    }

    func showPopoverDemo() {
        popover.showDemo(near: NSEvent.mouseLocation)
    }

    func showPopover(state: PopoverContentState, near point: NSPoint) {
        hideActionBar()
        popover.show(state: state, near: point)
    }

    func hidePopover() {
        popover.hide()
    }

    func showSettings(page: SettingsPage = .providers) {
        if onboarding.isVisible {
            onboarding.focus()
            return
        }
        hidePanel()
        hidePopover()
        hideActionBar()
        settings.show(page: page)
    }

    func showOnboarding() {
        NSApp.setActivationPolicy(.regular)
        onboarding.show()
    }

    func completeOnboarding() {
        let firstFinish = session?.onboardingCompleted == false
        session?.onboardingCompleted = true
        session?.saveNow()
        onboarding.close()
        applyDockPreference()
        showSettings(page: .providers)
        if firstFinish {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.statusItem?.showWelcomeHint()
            }
        }
    }

    func handleDeepLink(_ url: URL) {
        switch url.host {
        case "onboarding":
            showOnboarding()
        case "panel":
            showPanel()
        case "translate":
            translateSelection()
        case "auth", "auth-success", "settings":
            showSettings(page: .providers)
        default:
            break
        }
    }

    func applyDockPreference() {
        guard let session else { return }
        if session.showDockIcon {
            NSApp.setActivationPolicy(.regular)
            NSApp.dockTile.display()
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applyPanelPin() {
        panel.setPinned(session.panelPinned)
    }

    func applyAppearance() {
        guard let session else { return }
        switch session.appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
