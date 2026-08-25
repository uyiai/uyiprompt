import AppKit

/// AppKit owns process lifetime, the status item, URL scheme, and every product window.
/// SwiftUI is hosted inside AppKit windows. The SwiftUI `App` scene is only a launch stub.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var session: AppSession?
    private var windows: AppWindows?
    private var statusItem: StatusItemController?
    private var shortcuts: ShortcutService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        let bootDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("uyiprompt", isDirectory: true)
        try? FileManager.default.createDirectory(at: bootDir, withIntermediateDirectories: true)
        try? "didFinishLaunching\n".write(to: bootDir.appendingPathComponent("boot.log"), atomically: true, encoding: .utf8)

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

        let needsOnboarding = !session.onboardingCompleted
        let boot = "[uyiprompt] launched onboardingCompleted=\(needsOnboarding ? "no" : "yes")\n"
        try? boot.write(toFile: "/tmp/uyiprompt-debug.log", atomically: true, encoding: .utf8)
        if needsOnboarding {
            DispatchQueue.main.async { [weak windows] in
                windows?.showOnboarding()
            }
        } else {
            windows.applyDockPreference()
            DispatchQueue.main.async { [weak windows] in
                windows?.showSettings(page: .providers)
            }
        }
        dismissDummySwiftUIWindows()
        for delay in [0.05, 0.25, 0.8] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.dismissDummySwiftUIWindows()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func observeCommands() {
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings(_:)), name: .uyiOpenSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openOnboarding(_:)), name: .uyiOpenOnboarding, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openPanel(_:)), name: .uyiOpenPanel, object: nil)
    }

    private func dismissDummySwiftUIWindows() {
        let kept: Set<String> = [
            "uyiprompt.panel",
            "uyiprompt.popover",
            "uyiprompt.settings",
            "uyiprompt.onboarding",
            "uyiprompt.actionbar",
        ]
        for window in NSApp.windows {
            if let id = window.identifier?.rawValue, kept.contains(id) { continue }
            if window is NSPanel { continue }
            if window.className.contains("StatusBar") || window.className.contains("NSMenu") { continue }
            if window.title == "设置" || window.title == "欢迎" { continue }
            window.orderOut(nil)
        }
    }

    private func installMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu(title: "uyiprompt")
        appMenu.addItem(withTitle: "打开面板", action: #selector(openPanel(_:)), keyEquivalent: "u")
        appMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(withTitle: "模型服务", action: #selector(openProviders(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "设置…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        appMenu.addItem(withTitle: "使用说明", action: #selector(openOnboarding(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 uyiprompt", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
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
