import Foundation

/// Typed OpenAI-compatible chat request body. Building it as a value type
/// makes the provider × thinking matrix unit-testable.
struct ChatCompletionRequest: Encodable, Equatable {
    struct Message: Encodable, Equatable {
        var role: String
        var content: String
    }

    struct Thinking: Encodable, Equatable {
        var type: String
    }

    var model: String
    var messages: [Message]
    var temperature: Double?
    var maxTokens: Int?
    var maxCompletionTokens: Int?
    var reasoningEffort: String?
    var thinking: Thinking?
    var stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case maxCompletionTokens = "max_completion_tokens"
        case reasoningEffort = "reasoning_effort"
        case thinking
        case stream
    }

    static func build(
        model: String,
        system: String,
        user: String,
        maxTokens: Int,
        provider: LLMProvider?,
        thinking: Bool,
        temperature: Double,
        stream: Bool
    ) -> ChatCompletionRequest {
        var request = ChatCompletionRequest(
            model: model,
            messages: [
                Message(role: "system", content: system),
                Message(role: "user", content: user),
            ]
        )
        if ProviderCatalog.usesOpenAIReasoning(model) {
            request.maxCompletionTokens = thinking ? max(maxTokens, 8192) : max(maxTokens, 2048)
            request.reasoningEffort = thinking ? "medium" : "none"
        } else {
            request.temperature = temperature
            request.maxTokens = thinking ? max(maxTokens, 8192) : maxTokens
            switch provider?.thinkingPayload ?? .none {
            case .typeObject:
                request.thinking = Thinking(type: thinking ? "enabled" : "disabled")
                if thinking { request.reasoningEffort = "high" }
            case .none:
                if thinking, provider == .custom {
                    request.thinking = Thinking(type: "enabled")
                }
            }
        }
        if stream { request.stream = true }
        return request
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
