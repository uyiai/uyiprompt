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
    @State private var workTask: Task<Void, Never>?

    private var canRun: Bool {
        !busy && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 10) {
                if !session.llm.isReady {
                    SetupBanner(
                        icon: "key.fill",
                        text: L10n.t("panel.needKey"),
                        actionTitle: L10n.t("panel.fill")
                    ) {
                        windows.showSettings(page: .providers)
                    }
                } else if !accessibilityOn {
                    SetupBanner(
                        icon: "accessibility",
                        text: L10n.t("panel.needAccess"),
                        actionTitle: L10n.t("access.enable")
                    ) {
                        SelectionService.requestAccess()
                    }
                }

                HStack(spacing: 8) {
                    CapsuleChooser(
                        options: [(SelectionJob.enhance, L10n.t("job.enhance")), (.translate, L10n.t("job.translate"))],
                        selection: $panelJob
                    )
                    .frame(width: 148)
                    if panelJob == .enhance {
                        Picker(L10n.t("panel.style"), selection: $session.currentProfileID) {
                            ForEach(session.profiles) { profile in
                                Label(profile.localizedName, systemImage: profile.symbol).tag(profile.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    } else {
                        Picker(L10n.t("panel.into"), selection: $session.translateLanguage) {
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
        .background(UIChrome.canvasFill.opacity(0.55))
        .id(session.uiLanguage)
        .onAppear { applyPanelSeed(windows.panelSeed) }
        .onChange(of: windows.panelSeed) { _, seed in
            applyPanelSeed(seed)
        }
        .onDisappear {
            workTask?.cancel()
        }
        .onAppear { accessibilityOn = SelectionService.isTrusted }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityOn = SelectionService.isTrusted
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ColorTile(symbol: "pencil.and.outline", color: Color(red: 0.20, green: 0.48, blue: 1.00), size: 22)
            Text("uyiprompt")
                .font(.headline.weight(.semibold))
            Spacer()
            HStack(spacing: 4) {
                IconButton(symbol: session.panelPinned ? "pin.fill" : "pin", help: L10n.t("panel.pin"), active: session.panelPinned) {
                    session.panelPinned.toggle()
                    windows.applyPanelPin()
                }
                IconButton(symbol: "xmark", help: L10n.t("panel.hide")) {
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
                    Text(panelJob == .translate ? L10n.t("panel.placeholder.translate") : L10n.t("panel.placeholder.enhance"))
                        .foregroundStyle(.secondary)
                    Text(L10n.t("panel.placeholder.hint"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 96, maxHeight: result.isEmpty && error.isEmpty ? 220 : 120)
        .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
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
                        Button(L10n.t("panel.goKey")) { windows.showSettings(page: .providers) }
                            .controlSize(.small)
                    }
                }
            }
        } else if !result.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if panelJob == .enhance {
                        ResultViewToggle(mode: $mode)
                    }
                    Spacer()
                    Button(copied ? L10n.t("panel.copied") : L10n.t("panel.copy")) { copyResult() }
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
            Button(L10n.t("panel.hide")) { windows.hidePanel() }
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
            return panelJob == .translate ? L10n.t("panel.working.translate") : L10n.t("panel.working.enhance")
        }
        if result.isEmpty {
            return panelJob == .translate ? L10n.t("job.translate") : L10n.t("job.enhance")
        }
        return panelJob == .translate ? L10n.t("panel.again.translate") : L10n.t("panel.again.enhance")
    }

    private func applyPanelSeed(_ seed: AppWindows.PanelSeed?) {
        guard let seed else { return }
        draft = seed.text
        panelJob = seed.job
        result = ""
        error = ""
        windows.consumePanelSeed()
    }

    private func run() {
        let text = draft
        busy = true
        error = ""
        if panelJob == .enhance {
            mode = ResultViewMode.default(forProfileID: session.currentProfile.id)
        }
        let job = panelJob
        workTask?.cancel()
        workTask = Task { @MainActor in
            defer { busy = false }
            do {
                result = ""
                let finished = try await windows.rewriteDraft(text, job: job) { piece in
                    Task { @MainActor in
                        result += piece
                    }
                }
                result = finished
                windows.session.recordHistory(
                    job: job,
                    original: text,
                    result: result,
                    label: job == .translate ? L10n.t("job.translate") : session.currentProfile.localizedName
                )
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
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
