import Foundation

enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case deepseek
    case openai
    case moonshot
    case custom

    var id: String { rawValue }

    private var catalog: ProviderCatalog.Vendor { ProviderCatalog.vendor(self) }

    var title: String {
        if let key = catalog.titleKey { return L10n.t(key) }
        return catalog.title
    }

    var caption: String { L10n.t(catalog.captionKey) }
    var keyPlaceholder: String { catalog.keyPlaceholder }
    var signupURL: URL? { catalog.signupURL.flatMap(URL.init(string:)) }
    var helpText: String { L10n.t(catalog.helpKey) }
    var defaultBaseURL: String { catalog.defaultBaseURL }
    var suggestedModels: [String] { ProviderCatalog.pickerIDs(for: self) }
    var defaultModel: String { suggestedModels.first ?? "" }
    var supportsThinkingToggle: Bool { catalog.supportsThinking }
    var thinkingPayload: ProviderCatalog.ThinkingPayload { catalog.thinkingPayload }

    func displayName(for model: String) -> String {
        ProviderCatalog.displayName(provider: self, model: model)
    }
}

struct LLMProviderSettings: Codable, Equatable {
    var key: String
    var model: String
    var baseURL: String
    var thinkingEnabled: Bool

    static func preset(_ provider: LLMProvider) -> LLMProviderSettings {
        LLMProviderSettings(key: "", model: provider.defaultModel, baseURL: provider.defaultBaseURL, thinkingEnabled: false)
    }
}

struct LLMSettings: Equatable {
    var activeProvider: LLMProvider
    var providers: [LLMProvider: LLMProviderSettings]

    static let empty = LLMSettings(
        activeProvider: .deepseek,
        providers: Dictionary(uniqueKeysWithValues: LLMProvider.allCases.map { ($0, .preset($0)) })
    )

    var active: LLMProviderSettings {
        endpoint(activeProvider)
    }

    func endpoint(_ provider: LLMProvider) -> LLMProviderSettings {
        providers[provider] ?? .preset(provider)
    }

    func isConfigured(_ provider: LLMProvider) -> Bool {
        let settings = endpoint(provider)
        return !settings.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !settings.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func summary(for provider: LLMProvider) -> String {
        let settings = endpoint(provider)
        if settings.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return provider.caption
        }
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? L10n.t("model.hasKey") : model
    }

    var hasKey: Bool {
        !active.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasEndpoint: Bool {
        !active.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isReady: Bool {
        hasKey && hasEndpoint && !active.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var readySummary: String {
        if !hasKey { return L10n.t("model.missingKey") }
        if !hasEndpoint { return L10n.t("model.missingURL") }
        if active.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return L10n.t("model.missingModel") }
        let think = active.thinkingEnabled ? L10n.t("model.thinkingSuffix") : ""
        return "\(activeProvider.title) · \(activeProvider.displayName(for: active.model))\(think)"
    }

    mutating func migrateRetiredModels() {
        for provider in LLMProvider.allCases {
            var settings = endpoint(provider)
            let current = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let row = ProviderCatalog.model(provider, current), let replacement = row.replaceWith else {
                continue
            }
            settings.model = replacement
            if let thinking = row.replaceThinking {
                settings.thinkingEnabled = thinking
            }
            providers[provider] = settings
        }
    }
}

extension LLMSettings: Codable {
    private struct ProviderDTO: Codable {
        var key: String
        var model: String
        var baseURL: String?
        var thinkingEnabled: Bool?
    }

    private enum CodingKeys: String, CodingKey {
        case activeProvider
        case providers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let raw = try container.decodeIfPresent(String.self, forKey: .activeProvider),
           let parsed = LLMProvider(rawValue: raw) {
            activeProvider = parsed
        } else {
            activeProvider = .deepseek
        }
        let raw = try container.decodeIfPresent([String: ProviderDTO].self, forKey: .providers) ?? [:]
        var mapped: [LLMProvider: LLMProviderSettings] = LLMSettings.empty.providers
        for (key, value) in raw {
            if let provider = LLMProvider(rawValue: key) {
                mapped[provider] = LLMProviderSettings(
                    key: value.key,
                    model: value.model.isEmpty ? provider.defaultModel : value.model,
                    baseURL: (value.baseURL?.isEmpty == false) ? value.baseURL! : provider.defaultBaseURL,
                    thinkingEnabled: value.thinkingEnabled ?? false
                )
            }
        }
        providers = mapped
    }

    mutating func loadSecrets(from store: any SecretStore) {
        for provider in LLMProvider.allCases {
            var settings = endpoint(provider)
            let jsonKey = settings.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonKey.isEmpty {
                if let stored = store.get(account: provider.rawValue), !stored.isEmpty {
                    settings.key = stored
                    providers[provider] = settings
                }
            } else {
                store.set(jsonKey, account: provider.rawValue)
            }
        }
    }

    func saveSecrets(to store: any SecretStore) {
        for provider in LLMProvider.allCases {
            store.set(endpoint(provider).key, account: provider.rawValue)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activeProvider, forKey: .activeProvider)
        var raw: [String: ProviderDTO] = [:]
        for (provider, value) in providers {
            raw[provider.rawValue] = ProviderDTO(
                key: "",
                model: value.model,
                baseURL: value.baseURL,
                thinkingEnabled: value.thinkingEnabled
            )
        }
        try container.encode(raw, forKey: .providers)
    }
}

enum OpenAICompatibleEndpoint {
    static func chatCompletionsURL(from baseURL: String) throws -> URL {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard !base.isEmpty else { throw EnhanceError.missingBaseURL }
        if base.hasSuffix("/chat/completions") {
            guard let url = URL(string: base) else { throw EnhanceError.missingBaseURL }
            return url
        }
        if base.hasSuffix("/v1") {
            guard let url = URL(string: base + "/chat/completions") else { throw EnhanceError.missingBaseURL }
            return url
        }
        guard let url = URL(string: base + "/v1/chat/completions") else { throw EnhanceError.missingBaseURL }
        return url
    }
}
