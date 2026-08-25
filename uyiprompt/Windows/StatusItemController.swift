import AppKit

/// Left-click toggles the panel; right-click opens the menu — same as PromptDC.
@MainActor
final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private weak var windows: AppWindows?
    private var session: AppSession?
    private let hint = MenuBarHintController()

    func install(windows: AppWindows, session: AppSession) {
        self.windows = windows
        self.session = session
        windows.statusItem = self
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "pencil.and.outline", accessibilityDescription: "uyiprompt")
            image?.isTemplate = true
            button.image = image?.withSymbolConfiguration(.init(pointSize: 14, weight: .semibold))
            button.image?.isTemplate = true
            button.toolTip = L10n.t("status.tooltip")
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            button.action = #selector(statusItemClicked(_:))
        }
        item.menu = nil
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            windows?.showSettings(page: .providers)
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            windows?.showSettings(page: .providers)
        }
    }

    private func showMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        if session?.llm.isReady == false {
            menu.addItem(Self.item(L10n.t("menu.fillKey"), action: #selector(openProviders), target: self, symbol: "key"))
        }
        if SelectionService.isTrusted == false {
            menu.addItem(Self.item(L10n.t("menu.enableAccess"), action: #selector(openAccessibility), target: self, symbol: "accessibility"))
        }
        if session?.llm.isReady == false || SelectionService.isTrusted == false {
            menu.addItem(.separator())
        }
        menu.addItem(Self.item(L10n.t("menu.openPanel"), action: #selector(openPanel), target: self, symbol: "macwindow"))
        menu.addItem(Self.item(L10n.t("job.enhanceSelection"), action: #selector(enhanceSelection), target: self, symbol: "character.cursor.ibeam"))
        menu.addItem(Self.item(L10n.t("job.translateSelection"), action: #selector(translateSelection), target: self, symbol: "globe"))
        menu.addItem(Self.item(L10n.t("menu.providers"), action: #selector(openProviders), target: self, symbol: "cpu"))
        menu.addItem(Self.item(L10n.t("menu.settings"), action: #selector(openSettings), target: self, symbol: "gearshape", key: ","))
        menu.addItem(Self.item(L10n.t("menu.onboarding"), action: #selector(openOnboarding), target: self, symbol: "questionmark.circle"))
        menu.addItem(.separator())
        menu.addItem(recentMenuItem())
        menu.addItem(.separator())
        let currentName = session?.currentProfile.localizedName ?? L10n.t("profile.grammar")
        let active = NSMenuItem(title: L10n.format("menu.currentProfile", currentName), action: nil, keyEquivalent: "")
        active.image = NSImage(systemSymbolName: "text.book.closed", accessibilityDescription: nil)
        active.submenu = profileSubmenu()
        menu.addItem(active)
        menu.addItem(.separator())
        menu.addItem(Self.item(L10n.t("menu.quit"), action: #selector(quit), target: self, symbol: "power", key: "q"))
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    private func recentMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t("menu.recent"), action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
        let menu = NSMenu()
        let items = session?.history.items ?? []
        if items.isEmpty {
            menu.addItem(NSMenuItem(title: L10n.t("menu.noRecent"), action: nil, keyEquivalent: ""))
        } else {
            for entry in items.prefix(8) {
                let title = "\(entry.job == .translate ? L10n.t("job.translate") : entry.label) · \(entry.preview)"
                let row = NSMenuItem(title: String(title.prefix(60)), action: #selector(copyHistory(_:)), keyEquivalent: "")
                row.target = self
                row.representedObject = entry.id.uuidString
                menu.addItem(row)
            }
            menu.addItem(.separator())
            menu.addItem(Self.item(L10n.t("nav.history"), action: #selector(openHistory), target: self, symbol: "clock"))
        }
        item.submenu = menu
        return item
    }

    private func profileSubmenu() -> NSMenu {
        let menu = NSMenu()
        guard let session else {
            menu.addItem(NSMenuItem(title: L10n.t("menu.noProfiles"), action: nil, keyEquivalent: ""))
            return menu
        }
        for profile in session.profiles {
            let item = NSMenuItem(title: profile.localizedName, action: #selector(selectProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.id
            item.state = profile.id == session.currentProfileID ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private static func item(_ title: String, action: Selector, target: AnyObject, symbol: String? = nil, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return item
    }

    func applyLanguage() {
        statusItem?.button?.toolTip = L10n.t("status.tooltip")
    }

    func showWelcomeHint() {
        guard let button = statusItem?.button else { return }
        hint.show(from: button)
    }

    @objc private func openHistory() { windows?.showSettings(page: .history) }
    @objc private func copyHistory(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = session?.history.items.first(where: { $0.id.uuidString == id })
        else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.result, forType: .string)
    }
    @objc private func openPanel() { windows?.showPanel() }
    @objc private func enhanceSelection() { windows?.enhanceSelection() }
    @objc private func translateSelection() { windows?.translateSelection() }
    @objc private func openSettings() { windows?.showSettings(page: .general) }
    @objc private func openProviders() { windows?.showSettings(page: .providers) }
    @objc private func openOnboarding() { windows?.showOnboarding() }
    @objc private func openAccessibility() {
        SelectionService.requestAccess()
    }
    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        session?.currentProfileID = id
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
