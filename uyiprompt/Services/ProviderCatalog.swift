import Foundation

/// One place to update vendor titles, model ids, and retired aliases.
/// `LLMProvider` stays the Codable identity; this table is the data.
struct ProviderCatalog {
    struct Model: Equatable, Sendable {
        var id: String
        var brand: String
        var qualifierKey: String?
        var retired: Bool = false
        var replaceWith: String? = nil
        var replaceThinking: Bool? = nil
    }

    struct Vendor: Equatable, Sendable {
        var id: LLMProvider
        var title: String
        var titleKey: String? = nil
        var captionKey: String
        var helpKey: String
        var keyPlaceholder: String
        var signupURL: String? = nil
        var defaultBaseURL: String
        var supportsThinking: Bool
        var thinkingPayload: ThinkingPayload
        var keyOptional: Bool = false
        var models: [Model]
    }

    enum ThinkingPayload: Equatable, Sendable {
        case none
        case typeObject
    }

    static let vendors: [Vendor] = [
        Vendor(
            id: .deepseek,
            title: "DeepSeek",
            captionKey: "provider.deepseek.caption",
            helpKey: "provider.deepseek.help",
            keyPlaceholder: "sk-...",
            signupURL: "https://platform.deepseek.com/api_keys",
            defaultBaseURL: "https://api.deepseek.com/v1",
            supportsThinking: true,
            thinkingPayload: .typeObject,
            models: [
                Model(id: "deepseek-v4-flash", brand: "Flash", qualifierKey: "model.fast"),
                Model(id: "deepseek-v4-pro", brand: "Pro", qualifierKey: "model.strong"),
                Model(id: "deepseek-chat", brand: "Flash", qualifierKey: "model.oldName", retired: true, replaceWith: "deepseek-v4-flash", replaceThinking: false),
                Model(id: "deepseek-reasoner", brand: "", qualifierKey: "model.thinkingOld", retired: true, replaceWith: "deepseek-v4-flash", replaceThinking: true),
            ]
        ),
        Vendor(
            id: .openai,
            title: "OpenAI",
            captionKey: "provider.openai.caption",
            helpKey: "provider.openai.help",
            keyPlaceholder: "sk-...",
            signupURL: "https://platform.openai.com/api-keys",
            defaultBaseURL: "https://api.openai.com/v1",
            supportsThinking: true,
            thinkingPayload: .none,
            models: [
                Model(id: "gpt-5.6-luna", brand: "Luna", qualifierKey: "model.cheap"),
                Model(id: "gpt-5.6-terra", brand: "Terra", qualifierKey: "model.balanced"),
                Model(id: "gpt-5.6-sol", brand: "Sol", qualifierKey: "model.best"),
                Model(id: "gpt-4.1-mini", brand: "4.1 mini", retired: true, replaceWith: "gpt-5.6-luna"),
                Model(id: "gpt-4o-mini", brand: "4o mini", retired: true, replaceWith: "gpt-5.6-luna"),
                Model(id: "gpt-4.1", brand: "4.1", retired: true, replaceWith: "gpt-5.6-terra"),
                Model(id: "gpt-4o", brand: "4o", retired: true, replaceWith: "gpt-5.6-terra"),
            ]
        ),
        Vendor(
            id: .moonshot,
            title: "Kimi",
            captionKey: "provider.moonshot.caption",
            helpKey: "provider.moonshot.help",
            keyPlaceholder: "sk-...",
            signupURL: "https://platform.moonshot.cn/console/api-keys",
            defaultBaseURL: "https://api.moonshot.cn/v1",
            supportsThinking: true,
            thinkingPayload: .typeObject,
            models: [
                Model(id: "kimi-k2.6", brand: "K2.6", qualifierKey: "model.general"),
                Model(id: "kimi-k3", brand: "K3", qualifierKey: "model.flagship"),
                Model(id: "kimi-k2.7-code", brand: "K2.7", qualifierKey: "model.coding"),
                Model(id: "moonshot-v1-8k", brand: "K2.6", qualifierKey: "model.oldName", retired: true, replaceWith: "kimi-k2.6"),
                Model(id: "moonshot-v1-32k", brand: "K2.6", qualifierKey: "model.oldName", retired: true, replaceWith: "kimi-k2.6"),
                Model(id: "moonshot-v1-128k", brand: "K2.6", qualifierKey: "model.oldName", retired: true, replaceWith: "kimi-k2.6"),
            ]
        ),
        Vendor(
            id: .ollama,
            title: "Ollama",
            captionKey: "provider.ollama.caption",
            helpKey: "provider.ollama.help",
            keyPlaceholder: "",
            signupURL: "https://ollama.com/download",
            defaultBaseURL: "http://localhost:11434/v1",
            supportsThinking: false,
            thinkingPayload: .none,
            keyOptional: true,
            models: []
        ),
        Vendor(
            id: .lmstudio,
            title: "LM Studio",
            captionKey: "provider.lmstudio.caption",
            helpKey: "provider.lmstudio.help",
            keyPlaceholder: "",
            signupURL: "https://lmstudio.ai",
            defaultBaseURL: "http://localhost:1234/v1",
            supportsThinking: false,
            thinkingPayload: .none,
            keyOptional: true,
            models: []
        ),
        Vendor(
            id: .custom,
            title: "",
            titleKey: "provider.custom",
            captionKey: "provider.custom.caption",
            helpKey: "provider.custom.help",
            keyPlaceholder: "API Key",
            defaultBaseURL: "",
            supportsThinking: false,
            thinkingPayload: .none,
            models: []
        ),
    ]

    static func vendor(_ id: LLMProvider) -> Vendor {
        vendors.first(where: { $0.id == id }) ?? vendors[0]
    }

    static func pickerIDs(for id: LLMProvider) -> [String] {
        vendor(id).models.filter { !$0.retired }.map(\.id)
    }

    static func model(_ id: LLMProvider, _ model: String) -> Model? {
        vendor(id).models.first(where: { $0.id == model })
    }

    static func displayName(provider: LLMProvider, model: String) -> String {
        guard let row = self.model(provider, model) else { return model }
        let qualifier = row.qualifierKey.map(L10n.t) ?? ""
        if row.retired {
            if row.brand.isEmpty { return qualifier.isEmpty ? model : "\(qualifier)（\(L10n.t("model.oldName"))）" }
            if row.qualifierKey == "model.oldName" { return "\(row.brand)（\(qualifier)）" }
            if qualifier.isEmpty { return "\(row.brand)（\(L10n.t("model.oldName"))）" }
            return "\(row.brand)（\(qualifier)）"
        }
        if row.brand.isEmpty { return qualifier.isEmpty ? row.id : qualifier }
        if qualifier.isEmpty { return row.brand }
        return "\(row.brand) · \(qualifier)"
    }

    static func usesOpenAIReasoning(_ model: String) -> Bool {
        let name = model.lowercased()
        return name.hasPrefix("gpt-5") || name.hasPrefix("o1") || name.hasPrefix("o3") || name.hasPrefix("o4")
    }
}
