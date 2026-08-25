import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case providers
    case general
    case history
    case profiles
    case appDefaults
    case shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .providers: L10n.t("nav.providers")
        case .general: L10n.t("nav.general")
        case .history: L10n.t("nav.history")
        case .profiles: L10n.t("nav.profiles")
        case .appDefaults: L10n.t("nav.appDefaults")
        case .shortcuts: L10n.t("nav.shortcuts")
        }
    }

    var subtitle: String {
        switch self {
        case .providers: "选服务商、填密钥。和 Cherry Studio 一样，每个供应商单独配置。"
        case .general: "外观、权限、改写和翻译时的行为。"
        case .history: ""
        case .profiles: "每种风格是一套给模型的说明，可随时改。"
        case .appDefaults: "给邮件、编辑器等指定默认风格。"
        case .shortcuts: "全局有效，在别的软件里也能用。"
        }
    }

    var symbol: String {
        switch self {
        case .providers: "cpu.fill"
        case .general: "gearshape.fill"
        case .history: "clock.fill"
        case .profiles: "book.fill"
        case .appDefaults: "square.grid.2x2.fill"
        case .shortcuts: "keyboard.fill"
        }
    }

    var tileColor: Color {
        switch self {
        case .providers: Color(red: 0.20, green: 0.48, blue: 1.00)
        case .general: Color(red: 0.22, green: 0.22, blue: 0.24)
        case .history: Color(red: 0.20, green: 0.62, blue: 0.78)
        case .profiles: Color(red: 0.18, green: 0.40, blue: 0.95)
        case .appDefaults: Color(red: 0.45, green: 0.33, blue: 0.96)
        case .shortcuts: Color(red: 0.96, green: 0.52, blue: 0.18)
        }
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var session: AppSession?
    private weak var windows: AppWindows?
    private let model = SettingsModel()

    func attach(session: AppSession, windows: AppWindows) {
        self.session = session
        self.windows = windows
    }

    func show(page: SettingsPage) {
        model.page = page
        if page == .providers, let session {
            model.editingProvider = session.llm.activeProvider
        }
        let window = ensureWindow()
        applyMode()
        window.title = L10n.t("window.settings")
        ProductWindowFactory.present(window, size: WindowMetrics.settingsSignedIn)
    }

    private func applyMode() {
        guard let window else { return }
        window.setContentSize(WindowMetrics.settingsSignedIn)
        window.styleMask.insert(.resizable)
        window.minSize = CGSize(width: 760, height: 500)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        guard let session, let windows else {
            preconditionFailure("SettingsWindowController.attach must run first")
        }
        let created = ProductWindowFactory.makeSettingsWindow(size: WindowMetrics.settingsSignedIn)
        created.delegate = self
        created.center()
        created.contentViewController = GlassHostingController(
            rootView: SettingsView(model: model)
                .environmentObject(session)
                .environmentObject(windows),
            material: .underWindowBackground,
            blending: .withinWindow,
            emphasized: false
        )
        window = created
        return created
    }

    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        false
    }

    func windowWillClose(_ notification: Notification) {
        windows?.applyDockPreference()
    }
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var page: SettingsPage = .providers
    @Published var editingProvider: LLMProvider = .deepseek
}
