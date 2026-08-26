import AppKit

/// AppKit owns process lifetime, the status item, URL scheme, and every product window.
/// SwiftUI is hosted inside those windows; this type is the process entry point.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    private var session: AppSession?
    private var windows: AppWindows?
    private var statusItem: StatusItemController?
    private var shortcuts: ShortcutService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        let session = AppSession()
        let windows = AppWindows()
        let statusItem = StatusItemController()
        let shortcuts = ShortcutService()

        windows.attach(session: session)
        statusItem.install(windows: windows, session: session)
        shortcuts.install(windows: windows)
        windows.applyAppearance()

        self.session = session
        self.windows = windows
        self.statusItem = statusItem
        self.shortcuts = shortcuts
        installMainMenu()
        observeCommands()
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange(_:)), name: .uyiLanguageDidChange, object: nil)

        if isRunningUnderTests { return }
        _ = UpdateService.shared

        let needsOnboarding = !session.onboardingCompleted
        if needsOnboarding {
            DispatchQueue.main.async { [weak windows] in
                windows?.showOnboarding()
            }
        } else {
            windows.applyDockPreference()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private var isRunningUnderTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
    }

    private func observeCommands() {
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings(_:)), name: .uyiOpenSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openOnboarding(_:)), name: .uyiOpenOnboarding, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openPanel(_:)), name: .uyiOpenPanel, object: nil)
    }

    private func installMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu(title: "uyiprompt")
        appMenu.addItem(withTitle: L10n.t("menu.openPanel"), action: #selector(openPanel(_:)), keyEquivalent: "u")
        appMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(withTitle: L10n.t("menu.providers"), action: #selector(openProviders(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: L10n.t("menu.settings"), action: #selector(openSettings(_:)), keyEquivalent: ",")
        appMenu.addItem(withTitle: L10n.t("menu.onboarding"), action: #selector(openOnboarding(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: L10n.t("menu.checkUpdates"), action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: L10n.t("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        menu.addItem(editItem)
        let editMenu = NSMenu(title: L10n.t("menu.edit"))
        editMenu.addItem(withTitle: L10n.t("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L10n.t("menu.redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: L10n.t("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.t("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.t("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.t("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let windowItem = NSMenuItem()
        menu.addItem(windowItem)
        let windowMenu = NSMenu(title: L10n.t("menu.window"))
        windowMenu.addItem(withTitle: L10n.t("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: L10n.t("menu.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = menu
    }

    @objc private func openSettings(_ sender: Any?) {
        windows?.showSettings(page: .general)
    }

    @objc private func openProviders(_ sender: Any?) {
        windows?.showSettings(page: .providers)
    }

    @objc private func openPanel(_ sender: Any?) {
        windows?.showPanel()
    }

    @objc private func openOnboarding(_ sender: Any?) {
        windows?.showOnboarding()
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        UpdateService.shared.checkForUpdates()
    }

    @objc private func languageDidChange(_ sender: Any?) {
        installMainMenu()
        statusItem?.applyLanguage()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows?.showSettings(page: .providers)
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            windows?.handleDeepLink(url)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        session?.saveNow()
        shortcuts?.invalidate()
        windows?.invalidateSelectionWatcher()
    }
}
