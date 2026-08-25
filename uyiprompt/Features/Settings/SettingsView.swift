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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.page.title)
                                .font(.title.weight(.semibold))
                            Text(model.page.subtitle)
                                .foregroundStyle(.secondary)
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
                    Text("菜单栏改写 / 翻译")
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
                settingsBlock("外观") {
                    HStack {
                        Text("主题")
                        Spacer()
                        Picker("外观", selection: $session.appearance) {
                            ForEach(AppSession.AppearancePreference.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                        .onChange(of: session.appearance) { _, _ in
                            windows.applyAppearance()
                        }
                    }
                    .padding(12)
                }

                settingsBlock("改写语言") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("输出语言")
                            Text("自动会保持原文语言。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("语言", selection: $session.enhanceLanguage) {
                            ForEach(AppSession.EnhanceLanguage.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    .padding(12)
                }

                settingsBlock("翻译") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("目标语言")
                            Text("自动：中文译成英语，其它语言译成中文。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("译成", selection: $session.translateLanguage) {
                            ForEach(TranslateLanguage.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    .padding(12)
                }

                settingsBlock("权限") {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "accessibility")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(accessibilityOn ? Color.green : Color.orange)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("辅助功能")
                            Text("读取选中的文字，并把改写或译文写回去。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(
                            text: accessibilityOn ? "已开启" : "未开启",
                            tint: accessibilityOn ? .green : .red
                        )
                        if !accessibilityOn {
                            Button("去开启") {
                                SelectionService.requestAccess()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                }

                settingsBlock("桌面") {
                    VStack(spacing: 0) {
                        toggleRow("在程序坞显示图标", isOn: $session.showDockIcon) {
                            windows.applyDockPreference()
                        }
                        Divider().opacity(0.12).padding(.leading, 12)
                        toggleRow("面板始终置顶", isOn: $session.panelPinned) {
                            windows.applyPanelPin()
                        }
                        Divider().opacity(0.12).padding(.leading, 12)
                        toggleRow("改写后弹出结果窗", isOn: $session.enhancePopoverEnabled)
                        Divider().opacity(0.12).padding(.leading, 12)
                        VStack(alignment: .leading, spacing: 4) {
                            toggleRow("按快捷键后立刻开始改写", isOn: $session.autoEnhanceOnShortcut)
                            Text("关掉后，会先弹出窗口让你选风格再改写。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 10)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func settingsBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous)
                    .strokeBorder(UIChrome.cardStroke, lineWidth: 1)
            )
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>, onChange: @escaping () -> Void = {}) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onChange(of: isOn.wrappedValue) { _, _ in onChange() }
    }

    private var profilesPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("内置风格可改说明。也可以自己加一套。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    session.addCustomProfile()
                } label: {
                    Label("添加风格", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($session.profiles) { $profile in
                        profileCard($profile)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func profileCard(_ profile: Binding<WritingProfile>) -> some View {
        let current = session.currentProfileID == profile.wrappedValue.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: profile.wrappedValue.symbol)
                    .font(.body.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                TextField("名称", text: profile.name)
                    .font(.headline)
                    .textFieldStyle(.plain)
                Spacer()
                if current {
                    StatusPill(text: "当前", tint: Color.accentColor)
                } else {
                    Button("使用") { session.currentProfileID = profile.wrappedValue.id }
                        .controlSize(.small)
                }
                if !profile.wrappedValue.builtin {
                    Button("删除", role: .destructive) {
                        session.deleteProfile(profile.wrappedValue)
                    }
                    .controlSize(.small)
                }
            }
            TextField("给模型的说明", text: profile.systemPrompt, axis: .vertical)
                .font(.callout)
                .lineLimit(2...6)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous)
                .strokeBorder(current ? Color.accentColor.opacity(0.28) : UIChrome.cardStroke, lineWidth: 1)
        )
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
                Label("打开面板", systemImage: "macwindow")
            }
            LabeledContent {
                Text("⌘⇧E").font(.body.monospaced())
            } label: {
                Label("改写选中的文字", systemImage: "character.cursor.ibeam")
            }
            LabeledContent {
                Text("⌘⇧T").font(.body.monospaced())
            } label: {
                Label("翻译选中的文字", systemImage: "globe")
            }
            HowToStrip(shortcut: "⌘⇧E", action: "点「替换」")
            HowToStrip(shortcut: "⌘⇧T", action: "点「替换为译文」")
            Text("在微信、浏览器、编辑器里选中文字后按 ⌘⇧E 改写，或 ⌘⇧T 翻译。浏览器里 ⌘⇧T 可能是「重新打开标签页」，那时用面板里的翻译即可。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
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
