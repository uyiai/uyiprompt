import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case providers
    case general
    case profiles
    case appDefaults
    case shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .providers: "模型服务"
        case .general: "通用"
        case .profiles: "写作风格"
        case .appDefaults: "按应用"
        case .shortcuts: "快捷键"
        }
    }

    var subtitle: String {
        switch self {
        case .providers: "选服务商、填密钥。和 Cherry Studio 一样，每个供应商单独配置。"
        case .general: "外观、权限和改写时的行为。"
        case .profiles: "每种风格是一套给模型的说明，可随时改。"
        case .appDefaults: "给邮件、编辑器等指定默认风格。"
        case .shortcuts: "全局有效，在别的软件里也能用。"
        }
    }

    var symbol: String {
        switch self {
        case .providers: "cpu"
        case .general: "slider.horizontal.3"
        case .profiles: "text.book.closed"
        case .appDefaults: "square.grid.2x2"
        case .shortcuts: "keyboard"
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
        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        } else {
            ProductWindowFactory.present(window, size: WindowMetrics.settingsSignedIn)
        }
    }

    private func applyMode() {
        guard let window else { return }
        window.setContentSize(WindowMetrics.settingsSignedIn)
        window.styleMask.insert(.resizable)
        window.minSize = CGSize(width: 900, height: 620)
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
                .environmentObject(windows)
        )
        window = created
        return created
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
