import SwiftUI

struct ModuleMapView: View {
    private let rows: [Row] = [
        .init(
            surface: "Status item",
            electron: "Tray",
            host: "AppKit `NSStatusItem`",
            content: "AppKit `NSMenu`",
            why: "Left-click vs right-click must be split. SwiftUI MenuBarExtra cannot do this cleanly."
        ),
        .init(
            surface: "Enhance panel",
            electron: "panel.html + BrowserWindow",
            host: "AppKit `NSPanel` + `NSVisualEffectView`",
            content: "SwiftUI `PanelView`",
            why: "Always-on-top, all Spaces, fullscreen auxiliary, under-window glass."
        ),
        .init(
            surface: "Enhance popover",
            electron: "popover.html, focusable: false",
            host: "AppKit `NSPanel` + `.nonactivatingPanel`",
            content: "SwiftUI `PopoverView`",
            why: "Must not steal the source editor's selection. First click must hit controls."
        ),
        .init(
            surface: "Settings",
            electron: "settings.html, hiddenInset",
            host: "AppKit `NSWindow` + glass",
            content: "SwiftUI `SettingsView`",
            why: "Custom traffic-light layout and signed-in vs signed-out size. Do not use SwiftUI Settings scene."
        ),
        .init(
            surface: "Onboarding",
            electron: "onboarding.html",
            host: "AppKit `NSWindow` (opaque)",
            content: "SwiftUI `OnboardingView`",
            why: "Fixed size, first-run gate. Content is SwiftUI; the window is still AppKit so it can block other surfaces."
        ),
        .init(
            surface: "Selection / paste",
            electron: "selection.js",
            host: "ApplicationServices AX + CGEvent",
            content: "None",
            why: "AX + synthetic ⌘C/⌘V. Implemented in SelectionService."
        ),
        .init(
            surface: "Global shortcuts",
            electron: "globalShortcut",
            host: "ShortcutService (Carbon / NSEvent)",
            content: "None",
            why: "SwiftUI `.keyboardShortcut` only works while this app is key."
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AppKit host, SwiftUI content")
                .font(.title2.weight(.semibold))
            Text("Every product window is created in AppKit. SwiftUI draws what goes inside. The split is also written in docs/windows-and-modules.md.")
                .foregroundStyle(.secondary)

            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.surface)
                        .font(.headline)
                    LabeledContent("Electron") { Text(row.electron).textSelection(.enabled) }
                    LabeledContent("Window host") { Text(row.host).textSelection(.enabled) }
                    LabeledContent("Content") { Text(row.content).textSelection(.enabled) }
                    Text(row.why)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private struct Row: Identifiable {
        var surface: String
        var electron: String
        var host: String
        var content: String
        var why: String
        var id: String { surface }
    }
}
