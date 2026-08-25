import SwiftUI

@main
struct UyiPromptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // SwiftUI requires a Scene so NSApplication finishes launching.
        // Product windows stay AppKit-hosted.
        Settings {
            EmptyView()
                .frame(width: 1, height: 1)
        }
    }
}
