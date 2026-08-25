import Foundation

enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case deepseek
    case openai
    case moonshot
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deepseek: "DeepSeek"
        case .openai: "OpenAI"
        case .moonshot: "Kimi"
        case .custom: L10n.t("provider.custom")
        }
    }

    var caption: String {
        switch self {
        case .deepseek: L10n.t("provider.deepseek.caption")
        case .openai: L10n.t("provider.openai.caption")
        case .moonshot: L10n.t("provider.moonshot.caption")
        case .custom: L10n.t("provider.custom.caption")
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .deepseek: "sk-..."
        case .openai: "sk-..."
        case .moonshot: "sk-..."
        case .custom: "API Key"
        }
    }

    var signupURL: URL? {
        switch self {
        case .deepseek: URL(string: "https://platform.deepseek.com/api_keys")
        case .openai: URL(string: "https://platform.openai.com/api-keys")
        case .moonshot: URL(string: "https://platform.moonshot.cn/console/api-keys")
        case .custom: nil
        }
    }

    var helpText: String {
        switch self {
        case .deepseek: L10n.t("provider.deepseek.help")
        case .openai: L10n.t("provider.openai.help")
        case .moonshot: L10n.t("provider.moonshot.help")
        case .custom: L10n.t("provider.custom.help")
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .deepseek: "https://api.deepseek.com/v1"
        case .openai: "https://api.openai.com/v1"
        case .moonshot: "https://api.moonshot.cn/v1"
        case .custom: ""
        }
    }

    var suggestedModels: [String] {
        switch self {
        case .deepseek: ["deepseek-v4-flash", "deepseek-v4-pro"]
        case .openai: ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol"]
        case .moonshot: ["kimi-k2.6", "kimi-k3", "kimi-k2.7-code"]
        case .custom: []
        }
    }

    var defaultModel: String {
        suggestedModels.first ?? ""
    }

    var supportsThinkingToggle: Bool {
        self != .custom
    }

    func displayName(for model: String) -> String {
        switch model {
        case "deepseek-v4-flash": "Flash · \(L10n.t("model.fast"))"
        case "deepseek-v4-pro": "Pro · \(L10n.t("model.strong"))"
        case "deepseek-chat": "Flash（\(L10n.t("model.oldName"))）"
        case "deepseek-reasoner": "\(L10n.t("model.thinkingOld"))（\(L10n.t("model.oldName"))）"
        case "gpt-5.6-luna": "Luna · \(L10n.t("model.cheap"))"
        case "gpt-5.6-terra": "Terra · \(L10n.t("model.balanced"))"
        case "gpt-5.6-sol": "Sol · \(L10n.t("model.best"))"
        case "gpt-4.1-mini": "4.1 mini"
        case "gpt-4.1": "4.1"
        case "gpt-4o-mini": "4o mini"
        case "kimi-k2.6": "K2.6 · \(L10n.t("model.general"))"
        case "kimi-k3": "K3 · \(L10n.t("model.flagship"))"
        case "kimi-k2.7-code": "K2.7 · \(L10n.t("model.coding"))"
        case "moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k": "K2.6（\(L10n.t("model.oldName"))）"
        default: model
        }
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
        let aliases: [String: (model: String, thinking: Bool?)] = [
            "deepseek-chat": ("deepseek-v4-flash", false),
            "deepseek-reasoner": ("deepseek-v4-flash", true),
            "gpt-4.1-mini": ("gpt-5.6-luna", nil),
            "gpt-4o-mini": ("gpt-5.6-luna", nil),
            "gpt-4.1": ("gpt-5.6-terra", nil),
            "gpt-4o": ("gpt-5.6-terra", nil),
            "moonshot-v1-8k": ("kimi-k2.6", nil),
            "moonshot-v1-32k": ("kimi-k2.6", nil),
            "moonshot-v1-128k": ("kimi-k2.6", nil),
        ]
        for provider in LLMProvider.allCases {
            var settings = endpoint(provider)
            let current = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
            if let mapped = aliases[current] {
                settings.model = mapped.model
                if let thinking = mapped.thinking {
                    settings.thinkingEnabled = thinking
                }
                providers[provider] = settings
            }
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activeProvider, forKey: .activeProvider)
        var raw: [String: ProviderDTO] = [:]
        for (provider, value) in providers {
            raw[provider.rawValue] = ProviderDTO(
                key: value.key,
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
