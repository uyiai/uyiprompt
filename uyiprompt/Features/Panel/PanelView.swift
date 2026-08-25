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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            VStack(alignment: .leading, spacing: 10) {
                if !session.llm.isReady {
                    SetupBanner(
                        icon: "key.fill",
                        text: "还差 API Key，填上就能改写",
                        actionTitle: "去填写"
                    ) {
                        windows.showSettings(page: .providers)
                    }
                } else if !accessibilityOn {
                    SetupBanner(
                        icon: "accessibility",
                        text: "还没开辅助功能，无法读选中文字",
                        actionTitle: "去开启"
                    ) {
                        SelectionService.promptForAccessibility()
                        SelectionService.openAccessibilitySettings()
                    }
                }

                HStack(spacing: 8) {
                    Text("风格")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("风格", selection: $session.currentProfileID) {
                        ForEach(session.profiles) { profile in
                            Label(profile.name, systemImage: profile.symbol).tag(profile.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draft)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                    if draft.isEmpty {
                        Text("粘贴要改的文字，或在别的软件里选中后按 ⌘⇧E")
                            .foregroundStyle(.tertiary)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 88)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                if !error.isEmpty {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(Color.red)
                    if error.contains("密钥") || error.contains("API Key") {
                        Button("去填写密钥") { windows.showSettings(page: .providers) }
                            .controlSize(.small)
                    }
                } else if !result.isEmpty {
                    HStack {
                        ResultViewToggle(mode: $mode)
                        Spacer()
                        Button(copied ? "已复制" : "复制") { copyResult() }
                            .disabled(result.isEmpty)
                    }
                    ScrollView {
                        if mode == .changes {
                            ResultDiffView(original: draft, current: result)
                        } else {
                            Text(result)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxHeight: 140)
                }

                HStack {
                    Button("收起") { windows.hidePanel() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("⌘⇧U")
                    Spacer()
                    Button(busy ? "正在改写…" : (result.isEmpty ? "改写" : "再改一次")) { enhance() }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
        }
        .frame(minWidth: WindowMetrics.panelMinSize.width, minHeight: WindowMetrics.panelMinSize.height)
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
            Text("⌘⇧E")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .help("在别的软件里选中文字后按 ⌘⇧E")
            Button {
                session.panelPinned.toggle()
                windows.applyPanelPin()
            } label: {
                Image(systemName: session.panelPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.plain)
            .help("始终置顶")
            Button {
                windows.hidePanel()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("收起")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func enhance() {
        let profile = session.currentProfile
        let text = draft
        busy = true
        error = ""
        mode = ResultViewMode.default(forProfileID: profile.id)
        Task {
            defer { busy = false }
            do {
                result = try await EnhanceService.enhance(
                    message: text,
                    profilePrompt: profile.systemPrompt,
                    settings: session.llm,
                    language: session.enhanceLanguage
                )
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
        .frame(width: 360, height: 420)
}
