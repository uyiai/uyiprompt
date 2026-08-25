import AppKit
import SwiftUI

struct ModelSetupCard: View {
    @EnvironmentObject private var session: AppSession
    let provider: LLMProvider
    var compact: Bool = false
    var showProviderPicker: Bool = false
    var showsStatus: Bool = true
    var embedded: Bool = false

    @State private var revealKey = false
    @State private var testing = false
    @State private var testMessage = ""
    @State private var testOK = false

    private var endpoint: LLMProviderSettings { session.llm.endpoint(provider) }
    private var thisReady: Bool { session.llm.isConfigured(provider) }
    private var showModelField: Bool {
        provider.suggestedModels.isEmpty || (!compact && !provider.suggestedModels.contains(endpoint.model) && !endpoint.model.isEmpty)
    }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 14) {
            if showProviderPicker {
                providerPicker
            }

            if showsStatus {
                statusRow
            }

            field("API Key") {
                if let url = provider.signupURL {
                    Button("去申请密钥") { NSWorkspace.shared.open(url) }
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.semibold))
                }
            } content: {
                HStack(spacing: 8) {
                    Group {
                        if revealKey {
                            TextField(provider.keyPlaceholder, text: keyBinding)
                        } else {
                            SecureField("粘贴密钥，只存在这台电脑", text: keyBinding)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    Button {
                        revealKey.toggle()
                    } label: {
                        Image(systemName: revealKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                    .help(revealKey ? "隐藏密钥" : "显示密钥")
                }
            }

            field("模型") {
                EmptyView()
            } content: {
                if !provider.suggestedModels.isEmpty {
                    CapsuleChooser(options: modelOptions, selection: modelBinding)
                }
                if showModelField {
                    TextField("模型名，可手填", text: modelBinding)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if provider.supportsThinkingToggle {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("打开思考", isOn: thinkingBinding)
                    Text("改写一般不用开，更快更省。编程、长文、难改时再开。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if provider == .custom {
                field("接口地址") {
                    EmptyView()
                } content: {
                    TextField("https://api.example.com/v1", text: baseURLBinding)
                        .textFieldStyle(.roundedBorder)
                    Text("使用 OpenAI 兼容的 /v1/chat/completions。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if compact == false {
                DisclosureGroup("高级：接口地址") {
                    TextField(provider.defaultBaseURL, text: baseURLBinding)
                        .textFieldStyle(.roundedBorder)
                        .padding(.top, 6)
                    Text("一般不用改。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center, spacing: 10) {
                Button {
                    test()
                } label: {
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("测试连接", systemImage: "bolt.horizontal")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(testing)

                if !testMessage.isEmpty {
                    Text(testMessage)
                        .font(.callout)
                        .foregroundStyle(testOK ? Color.green : Color.red)
                        .lineLimit(2)
                }
            }
        }

        Group {
            if embedded {
                content
            } else {
                content
                    .padding(compact ? 12 : 16)
                    .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous)
                            .strokeBorder(UIChrome.cardStroke, lineWidth: 1)
                    )
            }
        }
        .onChange(of: provider) { _, _ in
            testMessage = ""
            testOK = false
            revealKey = false
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if testOK {
            Label("连接成功，可以用了", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
                .font(.callout.weight(.medium))
        } else if thisReady {
            Label("\(provider.title) · \(endpoint.model)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
                .font(.callout.weight(.medium))
        } else {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundStyle(provider.accent)
                Text(provider.helpText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func field<Trailing: View, Content: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                trailing()
            }
            content()
        }
    }

    private var providerPicker: some View {
        HStack(spacing: 8) {
            ForEach(LLMProvider.allCases) { item in
                Button {
                    applyPreset(item)
                } label: {
                    VStack(spacing: 6) {
                        ProviderIcon(provider: item, size: 32)
                        Text(item.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(session.llm.activeProvider == item ? Color.primary : .secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        session.llm.activeProvider == item ? Color.accentColor.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                session.llm.activeProvider == item ? Color.accentColor.opacity(0.4) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var modelOptions: [(String, String)] {
        var items = provider.suggestedModels.map { ($0, provider.displayName(for: $0)) }
        let current = endpoint.model
        if !current.isEmpty, !provider.suggestedModels.contains(current) {
            items.append((current, current))
        }
        return items
    }

    private func applyPreset(_ nextProvider: LLMProvider) {
        var next = session.llm
        var settings = next.endpoint(nextProvider)
        let knownDefaults = Set(LLMProvider.allCases.map(\.defaultBaseURL).filter { !$0.isEmpty })
        if settings.baseURL.isEmpty || knownDefaults.contains(settings.baseURL) {
            settings.baseURL = nextProvider.defaultBaseURL
        }
        if settings.model.isEmpty {
            settings.model = nextProvider.defaultModel
        }
        next.providers[nextProvider] = settings
        next.activeProvider = nextProvider
        if next != session.llm {
            session.llm = next
        }
        testMessage = ""
        testOK = false
    }

    private func update(_ mutate: (inout LLMProviderSettings) -> Void) {
        var next = session.llm
        var settings = next.endpoint(provider)
        mutate(&settings)
        next.providers[provider] = settings
        session.llm = next
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { endpoint.baseURL },
            set: { newValue in update { $0.baseURL = String(newValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)) } }
        )
    }

    private var keyBinding: Binding<String> {
        Binding(
            get: { endpoint.key },
            set: { newValue in
                update { $0.key = String(newValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000)) }
                testOK = false
            }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { endpoint.model },
            set: { newValue in update { $0.model = String(newValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)) } }
        )
    }

    private var thinkingBinding: Binding<Bool> {
        Binding(
            get: { endpoint.thinkingEnabled },
            set: { newValue in update { $0.thinkingEnabled = newValue } }
        )
    }

    private func test() {
        testing = true
        testMessage = ""
        testOK = false
        let target = session.llm.endpoint(provider)
        Task {
            defer { testing = false }
            do {
                _ = try await EnhanceService.testConnection(endpoint: target, provider: provider)
                testOK = true
                testMessage = "连接成功，可以用了"
                if session.llm.activeProvider != provider {
                    var next = session.llm
                    next.activeProvider = provider
                    session.llm = next
                }
                session.saveNow()
            } catch {
                testOK = false
                testMessage = error.localizedDescription
            }
        }
    }
}
