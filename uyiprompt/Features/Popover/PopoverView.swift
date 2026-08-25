import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: PopoverModel
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var windows: AppWindows
    @State private var mode: ResultViewMode = .changes
    @State private var copied = false
    var onClose: () -> Void
    var onReplace: () -> Void
    var onCopy: () -> Void
    var onRetry: () -> Void
    var onSwitchProfile: (String) -> Void
    var onSwitchLanguage: (TranslateLanguage) -> Void

    private var isTranslate: Bool { model.state.job == .translate }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.3)
            bodyContent
                .padding(12)
            Divider().opacity(0.3)
            footer
                .padding(12)
        }
        .frame(minWidth: WindowMetrics.popoverMin.width, minHeight: WindowMetrics.popoverMin.height)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.28))
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
                Picker("译成", selection: languageBinding) {
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
                Picker("写作风格", selection: profileBinding) {
                    ForEach(session.profiles) { profile in
                        Label(profile.name, systemImage: profile.symbol).tag(profile.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(model.state.status == .loading)
            }
            Spacer()
            IconButton(symbol: "xmark", help: "关闭", action: onClose)
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
                if !model.state.originalText.isEmpty {
                    Text(model.state.originalText)
                        .lineLimit(4)
                        .foregroundStyle(.tertiary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                if model.state.error.contains("辅助功能") || model.state.error.contains("Accessibility") {
                    Button("去系统设置重新授权") {
                        SelectionService.requestAccess()
                    }
                }
                if model.state.error.contains("API Key") || model.state.error.contains("密钥") {
                    Button("去填写密钥") {
                        windows.showSettings(page: .providers)
                    }
                }
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
                }
            }
        }
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
                Button("再试一次", action: onRetry)
            } else if model.state.status == .ready && model.state.enhancedText.isEmpty {
                Button(isTranslate ? "开始翻译" : "开始改写", action: onRetry)
                    .buttonStyle(.borderedProminent)
            } else {
                Button(copied ? "已复制" : "复制") {
                    onCopy()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                }
                .disabled(model.state.enhancedText.isEmpty)
            }
            Spacer()
            if !(model.state.status == .ready && model.state.enhancedText.isEmpty) {
                Button(action: onReplace) {
                    Label(isTranslate ? "替换为译文" : "替换原文", systemImage: "arrow.uturn.forward")
                }
                .buttonStyle(.borderedProminent)
                .help(isTranslate ? "用译文覆盖选中的文字" : "用改写结果覆盖选中的文字")
                .disabled(model.state.status != .ready || model.state.enhancedText.isEmpty)
            }
        }
    }

    private var loadingTitle: String {
        if isTranslate {
            let target = TranslateLanguage.resolve(model.state.translateLanguage, text: model.state.originalText)
            return "正在译成\(target.shortTitle)…"
        }
        return "正在用「\(model.state.profileName)」改写…"
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
