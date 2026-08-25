import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var windows: AppWindows
    @State private var apps: [InstalledApp] = []
    @State private var accessibilityOn = SelectionService.isTrusted

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)
            Divider().opacity(0.35)
            Group {
                if model.page == .providers {
                    ProviderSettingsView(editing: $model.editingProvider)
                        .padding(.top, 28)
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 10) {
                            Image(systemName: model.page.symbol)
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.page.title)
                                    .font(.title.weight(.semibold))
                                Text(model.page.subtitle)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        page
                    }
                    .padding(.top, 36)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if apps.isEmpty { apps = AppsService.list() }
            accessibilityOn = SelectionService.isTrusted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if apps.isEmpty { apps = AppsService.list() }
            accessibilityOn = SelectionService.isTrusted
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                AppMark(size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("uyiprompt")
                        .font(.headline)
                    Text("菜单栏改写")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 42)
            .padding(.bottom, 16)

            Text("设置")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)

            ForEach(SettingsPage.allCases) { page in
                SettingsNavRow(title: page.title, symbol: page.symbol, selected: model.page == page) {
                    model.page = page
                    if page == .providers {
                        model.editingProvider = session.llm.activeProvider
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                ProviderIcon(provider: session.llm.activeProvider, size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.llm.readySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("v0.1.0")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(10)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(Color.primary.opacity(0.03))
    }

    @ViewBuilder
    private var page: some View {
        switch model.page {
        case .providers: EmptyView()
        case .general: generalPage
        case .profiles: profilesPage
        case .appDefaults: appDefaultsPage
        case .shortcuts: shortcutsPage
        }
    }

    private var generalPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Form {
                    Section("外观") {
                        Picker("外观", selection: $session.appearance) {
                            ForEach(AppSession.AppearancePreference.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: session.appearance) { _, _ in
                            windows.applyAppearance()
                        }
                    }
                    Section("改写语言") {
                        Picker("语言", selection: $session.enhanceLanguage) {
                            ForEach(AppSession.EnhanceLanguage.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    }
                    Section("权限") {
                        LabeledContent("辅助功能") {
                            Text(accessibilityOn ? "已开启" : "未开启")
                                .foregroundStyle(accessibilityOn ? Color.secondary : Color.red)
                        }
                        if !accessibilityOn {
                            Button("去开启…") {
                                SelectionService.promptForAccessibility()
                                SelectionService.openAccessibilitySettings()
                            }
                        }
                        Text("用于读取选中的文字，并把改写结果粘贴回去。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("桌面") {
                        Toggle("在程序坞显示图标", isOn: $session.showDockIcon)
                            .onChange(of: session.showDockIcon) { _, _ in
                                windows.applyDockPreference()
                            }
                        Toggle("面板始终置顶", isOn: $session.panelPinned)
                            .onChange(of: session.panelPinned) { _, _ in
                                windows.applyPanelPin()
                            }
                        Toggle("改写后弹出结果窗", isOn: $session.enhancePopoverEnabled)
                        Toggle("按快捷键后立刻开始改写", isOn: $session.autoEnhanceOnShortcut)
                        Text("关掉后，会先弹出窗口让你选风格再改写。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var profilesPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("内置风格可改说明。也可以自己加一套。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("添加风格") { session.addCustomProfile() }
            }
            List {
                ForEach($session.profiles) { $profile in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: profile.symbol)
                                .font(.body)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 20)
                            TextField("名称", text: $profile.name)
                                .font(.headline)
                            Spacer()
                            if session.currentProfileID == profile.id {
                                Text("当前")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button("使用") { session.currentProfileID = profile.id }
                                .disabled(session.currentProfileID == profile.id)
                            if !profile.builtin {
                                Button("删除", role: .destructive) {
                                    session.deleteProfile(profile)
                                }
                            }
                        }
                        Text("给模型的说明")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("给模型的说明", text: $profile.systemPrompt, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    .padding(.vertical, 6)
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var appDefaultsPage: some View {
        List {
            ForEach(apps) { app in
                HStack(spacing: 10) {
                    Image(nsImage: AppsService.icon(for: app.path))
                        .resizable()
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.body.weight(.medium))
                        Text(app.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("风格", selection: ruleBinding(app.bundleID)) {
                        Text("跟随当前风格").tag("")
                        ForEach(session.profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var shortcutsPage: some View {
        Form {
            LabeledContent {
                Text("⌘⇧U").font(.body.monospaced())
            } label: {
                Label("打开改写面板", systemImage: "macwindow")
            }
            LabeledContent {
                Text("⌘⇧E").font(.body.monospaced())
            } label: {
                Label("改写选中的文字", systemImage: "character.cursor.ibeam")
            }
            HowToStrip()
            Text("在微信、浏览器、编辑器里选中文字后按 ⌘⇧E，改完点「替换原文」写回去。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func ruleBinding(_ bundleID: String) -> Binding<String> {
        Binding(
            get: { session.appProfileRules[bundleID] ?? "" },
            set: { newValue in
                var rules = session.appProfileRules
                if newValue.isEmpty {
                    rules.removeValue(forKey: bundleID)
                } else {
                    rules[bundleID] = newValue
                }
                session.appProfileRules = rules
            }
        )
    }

}

#Preview {
    SettingsView(model: SettingsModel())
        .environmentObject(AppSession())
        .environmentObject(AppWindows())
        .frame(width: 1020, height: 700)
}
