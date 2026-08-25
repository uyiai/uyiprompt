import AppKit
import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var windows: AppWindows
    @State private var draft = ""
    @State private var result = ""
    @State private var error = ""
    @State private var busy = false
    @State private var mode: ResultViewMode = .edit
    @State private var copied = false
    @State private var accessibilityOn = SelectionService.isTrusted
    @State private var panelJob: SelectionJob = .enhance

    private var canRun: Bool {
        !busy && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.22)
            VStack(alignment: .leading, spacing: 10) {
                if !session.llm.isReady {
                    SetupBanner(
                        icon: "key.fill",
                        text: "还差 API Key，填上就能改写和翻译",
                        actionTitle: "去填写"
                    ) {
                        windows.showSettings(page: .providers)
                    }
                } else if !accessibilityOn {
                    SetupBanner(
                        icon: "accessibility",
                        text: "辅助功能对不上当前程序，读不了选中文字",
                        actionTitle: "去开启"
                    ) {
                        SelectionService.requestAccess()
                    }
                }

                HStack(spacing: 8) {
                    CapsuleChooser(
                        options: [(SelectionJob.enhance, "改写"), (.translate, "翻译")],
                        selection: $panelJob
                    )
                    .frame(width: 148)
                    if panelJob == .enhance {
                        Picker("风格", selection: $session.currentProfileID) {
                            ForEach(session.profiles) { profile in
                                Label(profile.name, systemImage: profile.symbol).tag(profile.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    } else {
                        Picker("译成", selection: $session.translateLanguage) {
                            ForEach(TranslateLanguage.allCases) { language in
                                Text(language.shortTitle).tag(language)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        if !draft.isEmpty {
                            Text(TranslateLanguage.routeLabel(preference: session.translateLanguage, text: draft))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                .onChange(of: panelJob) { _, _ in
                    result = ""
                    error = ""
                    copied = false
                }

                editor
                resultBlock
                footer
            }
            .padding(12)
        }
        .frame(minWidth: WindowMetrics.panelMinSize.width, minHeight: WindowMetrics.panelMinSize.height)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.28))
        .onAppear { accessibilityOn = SelectionService.isTrusted }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityOn = SelectionService.isTrusted
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            AppMark(size: 22)
            Text("uyiprompt")
                .font(.headline)
            Spacer()
            HStack(spacing: 4) {
                ShortcutChip(text: "⌘⇧E", help: "选中文字后改写")
                ShortcutChip(text: "⌘⇧T", help: "选中文字后翻译")
                IconButton(symbol: session.panelPinned ? "pin.fill" : "pin", help: "始终置顶", active: session.panelPinned) {
                    session.panelPinned.toggle()
                    windows.applyPanelPin()
                }
                IconButton(symbol: "xmark", help: "收起") {
                    windows.hidePanel()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $draft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
            if draft.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(panelJob == .translate ? "粘贴要译的文字" : "粘贴要改的文字")
                        .foregroundStyle(.secondary)
                    Text(panelJob == .translate ? "或在别的软件里选中后按 ⌘⇧T" : "或在别的软件里选中后按 ⌘⇧E")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 96, maxHeight: result.isEmpty && error.isEmpty ? 220 : 120)
        .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(UIChrome.cardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var resultBlock: some View {
        if !error.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.red)
                VStack(alignment: .leading, spacing: 6) {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(Color.red)
                    if error.contains("密钥") || error.contains("API Key") {
                        Button("去填写密钥") { windows.showSettings(page: .providers) }
                            .controlSize(.small)
                    }
                }
            }
        } else if !result.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if panelJob == .enhance {
                        ResultViewToggle(mode: $mode)
                    } else {
                        Text("译文")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(copied ? "已复制" : "复制") { copyResult() }
                        .controlSize(.small)
                }
                ScrollView {
                    Group {
                        if panelJob == .translate {
                            Text(result)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if mode == .changes {
                            ResultDiffView(original: draft, current: result)
                        } else {
                            Text(result)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 128)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("收起") { windows.hidePanel() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("⌘⇧U")
            Spacer()
            Button(actionTitle) { run() }
                .buttonStyle(.borderedProminent)
                .disabled(!canRun)
                .opacity(canRun || busy ? 1 : 0.55)
        }
    }

    private var actionTitle: String {
        if busy {
            return panelJob == .translate ? "正在翻译…" : "正在改写…"
        }
        if result.isEmpty {
            return panelJob == .translate ? "翻译" : "改写"
        }
        return panelJob == .translate ? "再译一次" : "再改一次"
    }

    private func run() {
        let text = draft
        busy = true
        error = ""
        if panelJob == .enhance {
            mode = ResultViewMode.default(forProfileID: session.currentProfile.id)
        }
        let profile = session.currentProfile
        let language = session.translateLanguage
        let job = panelJob
        Task {
            defer { busy = false }
            do {
                switch job {
                case .enhance:
                    result = try await EnhanceService.enhance(
                        message: text,
                        profilePrompt: profile.systemPrompt,
                        settings: session.llm,
                        language: session.enhanceLanguage
                    )
                case .translate:
                    result = try await EnhanceService.translate(
                        message: text,
                        settings: session.llm,
                        language: language
                    )
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func copyResult() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}

#Preview {
    PanelView()
        .environmentObject(AppSession())
        .environmentObject(AppWindows())
        .frame(width: 380, height: 440)
}
