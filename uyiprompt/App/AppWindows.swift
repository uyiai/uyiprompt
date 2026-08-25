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
    let coordinator = EnhanceCoordinator()
    weak var statusItem: StatusItemController?

    var isOnboardingVisible: Bool { onboarding.isVisible }

    func attach(session: AppSession) {
        self.session = session
        panel.attach(session: session, windows: self)
        popover.attach(session: session, windows: self)
        settings.attach(session: session, windows: self)
        onboarding.attach(session: session, windows: self)
        coordinator.attach(session: session, windows: self)
        applyAppearance()
    }

    func togglePanel() {
        if onboarding.isVisible {
            onboarding.focus()
            return
        }
        panel.toggle()
    }

    func showPanel() {
        if onboarding.isVisible {
            onboarding.focus()
            return
        }
        panel.show()
    }

    func hidePanel() {
        panel.hide()
    }

    func enhanceSelection() {
        coordinator.enhanceSelection()
    }

    func showPopoverDemo() {
        popover.showDemo(near: NSEvent.mouseLocation)
    }

    func showPopover(state: PopoverContentState, near point: NSPoint) {
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
