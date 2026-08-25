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
        case .custom: "自定义"
        }
    }

    var caption: String {
        switch self {
        case .deepseek: "推荐 · 国内直连"
        case .openai: "官方接口"
        case .moonshot: "月之暗面"
        case .custom: "OpenAI 兼容"
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
        case .deepseek: "打开 DeepSeek 开放平台，创建 API Key 后粘贴过来。"
        case .openai: "打开 OpenAI 的 API keys 页面，创建密钥后粘贴过来。"
        case .moonshot: "打开 Moonshot 开放平台，创建 API Key 后粘贴过来。"
        case .custom: "填接口地址、密钥和模型名。需要兼容 OpenAI 的 /v1/chat/completions。"
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
        case .deepseek: ["deepseek-chat", "deepseek-reasoner"]
        case .openai: ["gpt-4.1-mini", "gpt-4.1", "gpt-4o-mini"]
        case .moonshot: ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"]
        case .custom: []
        }
    }

    var defaultModel: String {
        suggestedModels.first ?? ""
    }
}

struct LLMProviderSettings: Codable, Equatable {
    var key: String
    var model: String
    var baseURL: String

    static func preset(_ provider: LLMProvider) -> LLMProviderSettings {
        LLMProviderSettings(key: "", model: provider.defaultModel, baseURL: provider.defaultBaseURL)
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
        return model.isEmpty ? "已填密钥" : model
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
        if !hasKey { return "还差 API Key" }
        if !hasEndpoint { return "还差接口地址" }
        if active.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "还差模型名" }
        return "\(activeProvider.title) · \(active.model)"
    }
}

extension LLMSettings: Codable {
    private struct ProviderDTO: Codable {
        var key: String
        var model: String
        var baseURL: String?
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
                    baseURL: (value.baseURL?.isEmpty == false) ? value.baseURL! : provider.defaultBaseURL
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
            raw[provider.rawValue] = ProviderDTO(key: value.key, model: value.model, baseURL: value.baseURL)
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
