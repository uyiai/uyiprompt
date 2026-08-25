import SwiftUI

extension Notification.Name {
    static let uyiOpenSettings = Notification.Name("app.uyiprompt.openSettings")
    static let uyiOpenOnboarding = Notification.Name("app.uyiprompt.openOnboarding")
    static let uyiOpenPanel = Notification.Name("app.uyiprompt.openPanel")
}

@main
struct UyiPromptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // SwiftUI needs a Scene to finish launching. Do not use `Settings { EmptyView() }`:
        // that creates a blank 1×1 window, steals ⌘,, and makes Dock reopen a no-op.
        Window("uyiprompt-hidden", id: "uyiprompt.hidden") {
            Color.clear.frame(width: 1, height: 1)
        }
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    NotificationCenter.default.post(name: .uyiOpenSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button("使用说明") {
                    NotificationCenter.default.post(name: .uyiOpenOnboarding, object: nil)
                }
            }
        }
    }
}
