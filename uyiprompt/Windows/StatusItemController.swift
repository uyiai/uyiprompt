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
            button.toolTip = "uyiprompt · 选中文字后按 ⌘⇧E 改写"
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            button.action = #selector(statusItemClicked(_:))
        }
        item.menu = nil
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            windows?.togglePanel()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            windows?.togglePanel()
        }
    }

    private func showMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        if session?.llm.isReady == false {
            menu.addItem(Self.item("填写 API Key…", action: #selector(openProviders), target: self, symbol: "key"))
        }
        if SelectionService.isTrusted == false {
            menu.addItem(Self.item("开启辅助功能…", action: #selector(openAccessibility), target: self, symbol: "accessibility"))
        }
        if session?.llm.isReady == false || SelectionService.isTrusted == false {
            menu.addItem(.separator())
        }
        menu.addItem(Self.item("打开面板", action: #selector(openPanel), target: self, symbol: "macwindow"))
        menu.addItem(Self.item("模型服务", action: #selector(openProviders), target: self, symbol: "cpu"))
        menu.addItem(Self.item("设置…", action: #selector(openSettings), target: self, symbol: "gearshape", key: ","))
        menu.addItem(Self.item("使用说明", action: #selector(openOnboarding), target: self, symbol: "questionmark.circle"))
        menu.addItem(.separator())
        let currentName = session?.currentProfile.name ?? "校对"
        let active = NSMenuItem(title: "当前风格：\(currentName)", action: nil, keyEquivalent: "")
        active.image = NSImage(systemSymbolName: "text.book.closed", accessibilityDescription: nil)
        active.submenu = profileSubmenu()
        menu.addItem(active)
        menu.addItem(.separator())
        menu.addItem(Self.item("退出 uyiprompt", action: #selector(quit), target: self, symbol: "power", key: "q"))
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    private func profileSubmenu() -> NSMenu {
        let menu = NSMenu()
        guard let session else {
            menu.addItem(NSMenuItem(title: "还没有风格", action: nil, keyEquivalent: ""))
            return menu
        }
        for profile in session.profiles {
            let item = NSMenuItem(title: profile.name, action: #selector(selectProfile(_:)), keyEquivalent: "")
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

    func showWelcomeHint() {
        guard let button = statusItem?.button else { return }
        hint.show(from: button)
    }

    @objc private func openPanel() { windows?.showPanel() }
    @objc private func openSettings() { windows?.showSettings(page: .general) }
    @objc private func openProviders() { windows?.showSettings(page: .providers) }
    @objc private func openOnboarding() { windows?.showOnboarding() }
    @objc private func openAccessibility() {
        SelectionService.promptForAccessibility()
        SelectionService.openAccessibilitySettings()
    }
    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        session?.currentProfileID = id
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
