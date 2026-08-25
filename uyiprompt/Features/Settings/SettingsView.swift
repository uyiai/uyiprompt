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
                .frame(width: UIChrome.sidebarWidth)
            pageCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UIChrome.canvasFill)
        .ignoresSafeArea()
        .id(session.uiLanguage)
        .environment(\.locale, session.uiLanguage.locale)
        .onAppear {
            if apps.isEmpty { apps = AppsService.list() }
            accessibilityOn = SelectionService.isTrusted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if apps.isEmpty { apps = AppsService.list() }
            accessibilityOn = SelectionService.isTrusted
        }
    }

    private var pageCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                page
            }
            .padding(.top, 20)
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            Color.clear.frame(height: 36)

            ForEach(SettingsPage.allCases) { page in
                SettingsNavRow(
                    title: page.title,
                    symbol: page.symbol,
                    color: page.tileColor,
                    selected: model.page == page
                ) {
                    model.page = page
                    if page == .providers {
                        model.editingProvider = session.llm.activeProvider
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text("uyiprompt")
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(session.llm.isReady ? L10n.t("nav.connected") : L10n.t("nav.disconnected"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var page: some View {
        switch model.page {
        case .providers: ProviderSettingsView(editing: $model.editingProvider)
        case .general: generalPage
        case .profiles: profilesPage
        case .appDefaults: appDefaultsPage
        case .shortcuts: shortcutsPage
        }
    }

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsSection(title: L10n.t("appearance")) {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Text(L10n.t("appearance.theme"))
                        Spacer()
                        AppearanceChooser(selection: $session.appearance)
                            .onChange(of: session.appearance) { _, _ in
                                windows.applyAppearance()
                            }
                    }
                    .padding(16)
                    SettingsHairline()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("language.section"))
                                Text(L10n.t("language.caption"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        Picker(L10n.t("language.section"), selection: $session.uiLanguage) {
                            ForEach(AppLanguage.allCases) { item in
                                Text(item.pickerTitle).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(16)
                }
            }

            SettingsSection(title: L10n.t("section.language")) {
                languageRow(L10n.t("enhance.output"), caption: L10n.t("enhance.output.caption")) {
                    Picker(L10n.t("enhance.output"), selection: $session.enhanceLanguage) {
                        ForEach(AppSession.EnhanceLanguage.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                SettingsHairline()
                languageRow(L10n.t("translate.target"), caption: L10n.t("translate.target.caption")) {
                    Picker(L10n.t("translate.target"), selection: $session.translateLanguage) {
                        ForEach(TranslateLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
            }

            SettingsSection(title: L10n.t("section.permissions")) {
                HStack(alignment: .center, spacing: 10) {
                    ColorTile(
                        symbol: "accessibility",
                        color: accessibilityOn ? Color(red: 0.18, green: 0.72, blue: 0.36) : Color.orange,
                        size: 28
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("access.title"))
                        Text(L10n.t("access.caption"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !accessibilityOn {
                        Button(L10n.t("access.enable")) {
                            SelectionService.requestAccess()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    StatusPill(
                        text: accessibilityOn ? L10n.t("access.on") : L10n.t("access.off"),
                        tint: accessibilityOn ? .green : .orange
                    )
                }
                .padding(16)
            }

            SettingsSection(title: L10n.t("section.selection")) {
                VStack(alignment: .leading, spacing: 4) {
                    toggleRow(L10n.t("selection.actionBar"), isOn: $session.selectionActionBarEnabled)
                    Text(L10n.t("selection.actionBar.caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }

            SettingsSection(title: L10n.t("section.desktop")) {
                VStack(spacing: 0) {
                    toggleRow(L10n.t("desktop.dock"), isOn: $session.showDockIcon) {
                        windows.applyDockPreference()
                    }
                    SettingsHairline()
                    toggleRow(L10n.t("desktop.pin"), isOn: $session.panelPinned) {
                        windows.applyPanelPin()
                    }
                    SettingsHairline()
                    toggleRow(L10n.t("desktop.popover"), isOn: $session.enhancePopoverEnabled)
                    SettingsHairline()
                    VStack(alignment: .leading, spacing: 4) {
                        toggleRow(L10n.t("desktop.autoRun"), isOn: $session.autoEnhanceOnShortcut)
                        Text(L10n.t("desktop.autoRun.caption"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
    }

    private func languageRow<Control: View>(_ title: String, caption: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(16)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>, onChange: @escaping () -> Void = {}) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .onChange(of: isOn.wrappedValue) { _, _ in onChange() }
    }

    private var profilesPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("profiles.title"))
                    .font(.headline)
                Spacer()
                Button {
                    session.addCustomProfile()
                } label: {
                    Label(L10n.t("profiles.add"), systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            LazyVStack(spacing: 8) {
                ForEach($session.profiles) { $profile in
                    profileCard($profile)
                }
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
                TextField(L10n.t("profiles.name"), text: profile.name)
                    .font(.headline)
                    .textFieldStyle(.plain)
                Spacer()
                if current {
                    StatusPill(text: L10n.t("profiles.current"), tint: Color.accentColor)
                } else {
                    Button(L10n.t("profiles.use")) { session.currentProfileID = profile.wrappedValue.id }
                        .controlSize(.small)
                }
                if !profile.wrappedValue.builtin {
                    Button(L10n.t("profiles.delete"), role: .destructive) {
                        session.deleteProfile(profile.wrappedValue)
                    }
                    .controlSize(.small)
                }
            }
            TextField(L10n.t("profiles.prompt"), text: profile.systemPrompt, axis: .vertical)
                .font(.callout)
                .lineLimit(2...6)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(14)
        .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous)
                .strokeBorder(current ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
    }

    private var appDefaultsPage: some View {
        SettingsSection(title: L10n.t("nav.appDefaults")) {
            VStack(spacing: 0) {
                ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
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
                        Picker(L10n.t("appDefaults.profile"), selection: ruleBinding(app.bundleID)) {
                            Text(L10n.t("appDefaults.follow")).tag("")
                            ForEach(session.profiles) { profile in
                                Text(profile.localizedName).tag(profile.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    if index < apps.count - 1 {
                        SettingsHairline()
                    }
                }
            }
        }
    }

    private var shortcutsPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsSection(title: L10n.t("shortcuts.title")) {
                VStack(spacing: 0) {
                    shortcutRow(L10n.t("shortcuts.chips"), caption: L10n.t("shortcuts.chips.caption"), keys: [L10n.t("shortcuts.select"), L10n.t("job.enhance")])
                    SettingsHairline()
                    shortcutRow(L10n.t("shortcuts.panel"), caption: L10n.t("shortcuts.panel.caption"), keys: ["⌘", "⇧", "U"])
                }
            }
            HowToStrip(shortcut: L10n.t("howto.action"), action: L10n.t("howto.replace"))
            Text(L10n.t("shortcuts.help"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private func shortcutRow(_ title: String, caption: String, keys: [String]) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.caption.weight(.semibold).monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(16)
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
        .frame(width: 860, height: 580)
}
