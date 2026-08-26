import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: PopoverModel
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var windows: AppWindows
    @State private var mode: ResultViewMode = .changes
    @State private var copied = false
    @State private var refineText = ""
    var onClose: () -> Void
    var onReplace: () -> Void
    var onCopy: () -> Void
    var onRetry: () -> Void
    var onSwitchProfile: (String) -> Void
    var onSwitchLanguage: (TranslateLanguage) -> Void
    var onRefine: (String) -> Void = { _ in }

    private var isTranslate: Bool { model.state.job == .translate }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            bodyContent
                .padding(12)
            footer
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(minWidth: WindowMetrics.popoverMin.width, minHeight: WindowMetrics.popoverMin.height)
        .background(UIChrome.canvasFill.opacity(0.55))
        .id(session.uiLanguage)
        .onChange(of: model.state.profileId) { _, id in
            mode = isTranslate ? .edit : ResultViewMode.default(forProfileID: id)
        }
        .onChange(of: model.state.job) { _, _ in
            mode = isTranslate ? .edit : ResultViewMode.default(forProfileID: model.state.profileId)
        }
        .onAppear {
            mode = isTranslate ? .edit : ResultViewMode.default(forProfileID: model.state.profileId)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if isTranslate {
                Image(systemName: "globe")
                    .foregroundStyle(Color.accentColor)
                    .font(.body.weight(.semibold))
                Picker(L10n.t("panel.into"), selection: languageBinding) {
                    ForEach(TranslateLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(model.state.status == .loading)
                if !model.state.originalText.isEmpty {
                    Text(TranslateLanguage.routeLabel(preference: model.state.translateLanguage, text: model.state.originalText))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Picker(L10n.t("panel.style"), selection: profileBinding) {
                    ForEach(session.profiles) { profile in
                        Label(profile.localizedName, systemImage: profile.symbol).tag(profile.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(model.state.status == .loading)
            }
            Spacer()
            IconButton(symbol: "xmark", help: L10n.t("popover.close"), action: onClose)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch model.state.status {
        case .loading:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(loadingTitle)
                        .foregroundStyle(.secondary)
                }
                ScrollView {
                    Text(model.state.enhancedText.isEmpty ? model.state.originalText : model.state.enhancedText)
                        .textSelection(.enabled)
                        .foregroundStyle(model.state.enhancedText.isEmpty ? .tertiary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .error:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                    Text(model.state.error)
                        .foregroundStyle(Color.red)
                }
                recoveryActions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                if isTranslate {
                    translateResult
                } else {
                    if !model.state.enhancedText.isEmpty {
                        ResultViewToggle(mode: $mode)
                    }
                    ScrollView {
                        if model.state.enhancedText.isEmpty {
                            Text(model.state.originalText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if mode == .changes {
                            ResultDiffView(original: model.state.originalText, current: model.state.enhancedText)
                        } else {
                            Text(model.state.enhancedText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if !model.state.enhancedText.isEmpty {
                        refineBar
                    }
                }
            }
        }
    }

    /// Quick follow-up rewrites on the current result.
    private var refineBar: some View {
        HStack(spacing: 6) {
            refineChip(L10n.t("refine.shorter"), instruction: "Make it shorter")
            refineChip(L10n.t("refine.formal"), instruction: "Make it more formal")
            refineChip(L10n.t("refine.casual"), instruction: "Make it more casual and conversational")
            TextField(L10n.t("refine.placeholder"), text: $refineText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .onSubmit {
                    let instruction = refineText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !instruction.isEmpty else { return }
                    refineText = ""
                    onRefine(instruction)
                }
        }
    }

    private func refineChip(_ title: String, instruction: String) -> some View {
        Button(title) { onRefine(instruction) }
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    @ViewBuilder
    private var recoveryActions: some View {
        switch model.state.recovery {
        case .none:
            EmptyView()
        case .accessibility:
            Button(L10n.t("popover.reauth")) {
                SelectionService.requestAccess()
            }
            Button(L10n.t("recovery.openPanel")) {
                openPanelWithAvailableText()
            }
        case .apiKey:
            Button(L10n.t("panel.goKey")) {
                windows.showSettings(page: .providers)
            }
        case .emptySelection:
            Button(L10n.t("recovery.openPanel")) {
                windows.showPanel(job: model.state.job)
            }
            .buttonStyle(.borderedProminent)
        case .pasteFailed:
            Button(L10n.t("recovery.continueInPanel")) {
                openPanelWithAvailableText()
            }
            .buttonStyle(.borderedProminent)
            if !model.state.originalText.isEmpty {
                Button(L10n.t("recovery.copyOriginal")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.state.originalText, forType: .string)
                }
            }
        }
    }

    private func openPanelWithAvailableText() {
        let text = model.state.enhancedText.isEmpty ? model.state.originalText : model.state.enhancedText
        windows.showPanel(draft: text.isEmpty ? nil : text, job: model.state.job)
    }

    @ViewBuilder
    private var translateResult: some View {
        ScrollView {
            Text(model.state.enhancedText.isEmpty ? model.state.originalText : model.state.enhancedText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            if model.state.status == .error {
                Button(L10n.t("popover.retry"), action: onRetry)
            } else if model.state.status == .ready && model.state.enhancedText.isEmpty {
                Button(isTranslate ? L10n.t("popover.start.translate") : L10n.t("popover.start.enhance"), action: onRetry)
                    .buttonStyle(.borderedProminent)
            } else {
                Button(copied ? L10n.t("panel.copied") : L10n.t("panel.copy")) {
                    onCopy()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                }
                .disabled(model.state.enhancedText.isEmpty)
            }
            Spacer()
            if !(model.state.status == .ready && model.state.enhancedText.isEmpty) {
                Button(action: onReplace) {
                    Label(isTranslate ? L10n.t("popover.replace.translate") : L10n.t("popover.replace.enhance"), systemImage: "arrow.uturn.forward")
                }
                .buttonStyle(.borderedProminent)
                .help(isTranslate ? L10n.t("popover.replace.help.translate") : L10n.t("popover.replace.help.enhance"))
                .disabled(model.state.status != .ready || model.state.enhancedText.isEmpty)
            }
        }
    }

    private var loadingTitle: String {
        if isTranslate {
            let target = TranslateLanguage.resolve(model.state.translateLanguage, text: model.state.originalText)
            return L10n.format("popover.loading.translate", target.shortTitle)
        }
        return L10n.format("popover.loading.enhance", model.state.profileName)
    }

    private var profileBinding: Binding<String> {
        Binding(
            get: { model.state.profileId.isEmpty ? session.currentProfileID : model.state.profileId },
            set: { onSwitchProfile($0) }
        )
    }

    private var languageBinding: Binding<TranslateLanguage> {
        Binding(
            get: { model.state.translateLanguage },
            set: { onSwitchLanguage($0) }
        )
    }
}

#Preview {
    PopoverView(
        model: PopoverModel(
            state: PopoverContentState(
                status: .ready,
                profileId: "grammar",
                profileName: "Grammar",
                originalText: "lets meet tmrw",
                enhancedText: "Let's meet tomorrow.",
                error: "",
                job: .enhance
            )
        ),
        onClose: {},
        onReplace: {},
        onCopy: {},
        onRetry: {},
        onSwitchProfile: { _ in },
        onSwitchLanguage: { _ in }
    )
    .environmentObject(AppSession())
    .environmentObject(AppWindows())
    .frame(width: 380, height: 260)
}
