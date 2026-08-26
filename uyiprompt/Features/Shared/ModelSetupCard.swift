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
    @State private var fetchingModels = false
    @State private var fetchedModels: [String] = []
    @State private var fetchMessage = ""

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

            field(L10n.t("model.apiKey")) {
                if let url = provider.signupURL {
                    Button(L10n.t("model.getKey")) { NSWorkspace.shared.open(url) }
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.semibold))
                }
            } content: {
                HStack(spacing: 8) {
                    Group {
                        if revealKey {
                            TextField(provider.keyPlaceholder, text: keyBinding)
                        } else {
                            SecureField(L10n.t("model.keyPlaceholder"), text: keyBinding)
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
                    .help(revealKey ? L10n.t("model.hideKey") : L10n.t("model.showKey"))
                }
            }

            field(L10n.t("model.model")) {
                if provider == .custom {
                    Button {
                        fetchModels()
                    } label: {
                        if fetchingModels {
                            ProgressView().controlSize(.mini)
                        } else {
                            Text(L10n.t("model.fetch"))
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                    .disabled(fetchingModels || endpoint.baseURL.isEmpty)
                }
            } content: {
                if !provider.suggestedModels.isEmpty {
                    CapsuleChooser(options: modelOptions, selection: modelBinding)
                }
                if provider == .custom, !fetchedModels.isEmpty {
                    Picker(L10n.t("model.model"), selection: modelBinding) {
                        if !endpoint.model.isEmpty, !fetchedModels.contains(endpoint.model) {
                            Text(endpoint.model).tag(endpoint.model)
                        }
                        ForEach(fetchedModels, id: \.self) { id in
                            Text(id).tag(id)
                        }
                    }
                    .labelsHidden()
                }
                if showModelField {
                    TextField(L10n.t("model.modelPlaceholder"), text: modelBinding)
                        .textFieldStyle(.roundedBorder)
                }
                if !fetchMessage.isEmpty {
                    Text(fetchMessage)
                        .font(.caption)
                        .foregroundStyle(fetchedModels.isEmpty ? Color.red : Color.secondary)
                        .lineLimit(2)
                }
            }

            if provider.supportsThinkingToggle {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(L10n.t("model.thinking"), isOn: thinkingBinding)
                        .toggleStyle(.switch)
                    Text(L10n.t("model.thinking.caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if provider == .custom {
                field(L10n.t("model.baseURL")) {
                    EmptyView()
                } content: {
                    TextField("https://api.example.com/v1", text: baseURLBinding)
                        .textFieldStyle(.roundedBorder)
                    Text(L10n.t("model.baseURL.caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if compact == false {
                DisclosureGroup(L10n.t("model.advancedURL")) {
                    TextField(provider.defaultBaseURL, text: baseURLBinding)
                        .textFieldStyle(.roundedBorder)
                        .padding(.top, 6)
                    Text(L10n.t("model.advancedURL.caption"))
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
                        Label(L10n.t("model.test"), systemImage: "bolt.horizontal")
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
            fetchedModels = []
            fetchMessage = ""
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if testOK {
            Label(L10n.t("model.testOK"), systemImage: "checkmark.circle.fill")
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

    private func fetchModels() {
        fetchingModels = true
        fetchMessage = ""
        let target = session.llm.endpoint(provider)
        Task {
            defer { fetchingModels = false }
            do {
                let models = try await ModelsService.listModels(baseURL: target.baseURL, key: target.key)
                fetchedModels = models
                if models.isEmpty {
                    fetchMessage = L10n.t("model.fetchEmpty")
                } else {
                    fetchMessage = L10n.format("model.fetched", models.count)
                    if endpoint.model.isEmpty, let first = models.first {
                        update { $0.model = first }
                    }
                }
            } catch {
                fetchedModels = []
                fetchMessage = error.localizedDescription
            }
        }
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
                testMessage = L10n.t("model.testOK")
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
