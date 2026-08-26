import Foundation

enum EnhanceError: LocalizedError, Equatable {
    case missingAPIKey
    case missingBaseURL
    case missingModel
    case emptyInput
    case tooLong
    case http(Int, String)
    case network(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return L10n.t("error.missingKey")
        case .missingBaseURL:
            return L10n.t("error.missingURL")
        case .missingModel:
            return L10n.t("error.missingModel")
        case .emptyInput:
            return L10n.t("error.empty")
        case .tooLong:
            return L10n.t("error.tooLong")
        case .http(let code, let body):
            return friendlyHTTP(code, body)
        case .network(let message):
            return message.isEmpty ? L10n.t("error.network") : message
        case .emptyResponse:
            return L10n.t("error.emptyResponse")
        }
    }

    private func friendlyHTTP(_ code: Int, _ body: String) -> String {
        if code == 401 || code == 403 { return L10n.t("error.http401") }
        if code == 429 { return L10n.t("error.http429") }
        if code == 404 { return L10n.t("error.http404") }
        if !body.isEmpty { return L10n.format("error.httpBody", code, body) }
        return L10n.format("error.http", code)
    }

    var popoverCode: String {
        switch self {
        case .missingAPIKey: return "API_KEY_REQUIRED"
        case .tooLong: return "MESSAGE_TOO_LONG"
        case .network: return "NETWORK_ERROR"
        default: return "ENHANCE_FAILED"
        }
    }
}

/// Direct OpenAI-compatible BYOK call.
enum EnhanceService {
    static let messageMax = 50_000

    /// No cookies, no cache — API calls leave nothing on disk.
    private static let urlSession = URLSession(configuration: .ephemeral)

    struct ValidatedEndpoint {
        var message: String
        var key: String
        var model: String
        var url: URL
        var endpoint: LLMProviderSettings
    }

    /// Shared trim/key/model/URL validation for enhance and translate.
    static func validate(message: String, settings: LLMSettings) throws -> ValidatedEndpoint {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw EnhanceError.emptyInput }
        if trimmed.count > messageMax { throw EnhanceError.tooLong }
        let endpoint = settings.active
        let key = endpoint.key.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { throw EnhanceError.missingAPIKey }
        let model = endpoint.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.isEmpty { throw EnhanceError.missingModel }
        let url = try OpenAICompatibleEndpoint.chatCompletionsURL(from: endpoint.baseURL)
        return ValidatedEndpoint(message: trimmed, key: key, model: model, url: url, endpoint: endpoint)
    }

    /// Long inputs need room for a comparable-length output; 4096 tokens truncates.
    static func scaledMaxTokens(forInputLength length: Int, floor minimum: Int = 4096) -> Int {
        min(16_384, max(minimum, length))
    }

    /// Some models leak chain-of-thought as <think>…</think> inside content.
    static func stripThink(_ text: String) -> String {
        var result = text
        while let open = result.range(of: "<think>"),
              let close = result.range(of: "</think>", range: open.upperBound..<result.endIndex) {
            result.removeSubrange(open.lowerBound..<close.upperBound)
        }
        result = result.replacingOccurrences(of: "<think>", with: "")
        result = result.replacingOccurrences(of: "</think>", with: "")
        return result
    }

    /// Map URLSession failures to something diagnosable; never swallow cancellation.
    static func mapTransport(_ error: Error) -> Error {
        if error is CancellationError { return error }
        guard let urlError = error as? URLError else {
            return EnhanceError.network("")
        }
        if urlError.code == .cancelled { return CancellationError() }
        switch urlError.code {
        case .timedOut:
            return EnhanceError.network(L10n.t("error.timeout"))
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return EnhanceError.network(L10n.t("error.offline"))
        case .cannotFindHost, .dnsLookupFailed:
            return EnhanceError.network(L10n.t("error.dns"))
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected:
            return EnhanceError.network(L10n.t("error.tls"))
        default:
            return EnhanceError.network(urlError.localizedDescription)
        }
    }

    /// Pull a human-readable message out of an OpenAI-style error body.
    private static func errorDetail(from data: Data) -> String {
        var detail = String(data: data, encoding: .utf8) ?? ""
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let err = object["error"] as? [String: Any], let message = err["message"] as? String {
                detail = message
            } else if let message = object["message"] as? String {
                detail = message
            }
        }
        return String(detail.prefix(200))
    }
    static let outputOnlyRules =
        "Return ONLY the transformed text. Never include meta commentary, explanations, apologies, " +
        "claims about being an AI, training-data or knowledge-cutoff statements. Preserve every " +
        "@mention, #hashtag, URL, and emoji from the input VERBATIM."

    static func delimit(_ message: String) -> String {
        SelectionFence.wrap(message)
    }

    static func harden(_ profilePrompt: String) -> String {
        let prompt = profilePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if prompt.isEmpty {
            return "You rewrite text.\n\nCritical input rule: \(SelectionFence.inputRule)\nCritical output rules: \(outputOnlyRules)"
        }
        return "\(prompt)\n\nCritical input rule: \(SelectionFence.inputRule)\nCritical output rules: \(outputOnlyRules)"
    }

    static func enhance(
        message: String,
        profilePrompt: String,
        settings: LLMSettings,
        language: AppSession.EnhanceLanguage = .auto,
        codingTarget: String? = nil,
        onDelta: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let validated = try validate(message: message, settings: settings)
        let trimmed = validated.message
        let endpoint = validated.endpoint

        var system = harden(profilePrompt)
        if language == .auto {
            system += "\nKeep the original language of the text unless asked otherwise."
        } else {
            system += "\nWrite the result in \(language.promptName)."
        }
        if let codingTarget {
            system += "\n\(codingTarget)"
        }
        let user = delimit(trimmed)

        let output = try await chatCompletions(
            url: validated.url,
            key: validated.key,
            model: validated.model,
            system: system,
            user: user,
            maxTokens: scaledMaxTokens(forInputLength: trimmed.count),
            provider: settings.activeProvider,
            thinking: endpoint.thinkingEnabled,
            stream: true,
            onDelta: onDelta
        )
        let cleaned = stripThink(SelectionFence.strip(output)).trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { throw EnhanceError.emptyResponse }
        return cleaned
    }

    static func translate(
        message: String,
        settings: LLMSettings,
        language: TranslateLanguage,
        onDelta: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let validated = try validate(message: message, settings: settings)
        let trimmed = validated.message

        let resolved = TranslateLanguage.resolve(language, text: trimmed)
        let target = resolved.promptName
        let system = """
        You are a professional translator.
        Translate the data between the delimiters into \(target).
        Critical input rule: \(SelectionFence.inputRule)
        Critical output rules: \(outputOnlyRules)
        Extra translation rules:
        - Output ONLY the translation. No preface, notes, quotes around the whole text, or bilingual dump.
        - Preserve URLs, @mentions, #hashtags, code identifiers, file paths, numbers, and emoji exactly.
        - Preserve markdown, line breaks, and list structure.
        - Keep the author's tone.
        - Do not translate fenced code; keep code as-is and translate natural-language comments.
        - If the source is already in the target language, return it unchanged.
        """
        let user = delimit(trimmed)
        let output = try await chatCompletions(
            url: validated.url,
            key: validated.key,
            model: validated.model,
            system: system,
            user: user,
            maxTokens: scaledMaxTokens(forInputLength: trimmed.count, floor: 8192),
            provider: settings.activeProvider,
            thinking: false,
            temperature: 0.2,
            stream: true,
            onDelta: onDelta
        )
        let cleaned = stripThink(SelectionFence.strip(output)).trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { throw EnhanceError.emptyResponse }
        return cleaned
    }

    /// Tiny chat call so the user can verify Base URL + key + model.
    static func testConnection(settings: LLMSettings) async throws -> String {
        try await testConnection(endpoint: settings.active)
    }

    static func testConnection(endpoint: LLMProviderSettings, provider: LLMProvider? = nil) async throws -> String {
        let key = endpoint.key.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { throw EnhanceError.missingAPIKey }
        let model = endpoint.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.isEmpty { throw EnhanceError.missingModel }
        let url = try OpenAICompatibleEndpoint.chatCompletionsURL(from: endpoint.baseURL)
        let reply = try await chatCompletions(
            url: url,
            key: key,
            model: model,
            system: "You are a connection check. Reply with the single word pong.",
            user: "ping",
            maxTokens: 16,
            provider: provider,
            thinking: false
        )
        return reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func chatCompletions(
        url: URL,
        key: String,
        model: String,
        system: String,
        user: String,
        maxTokens: Int = 4096,
        provider: LLMProvider?,
        thinking: Bool,
        temperature: Double = 0.3,
        stream: Bool = false,
        onDelta: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        let openaiReasoning = ProviderCatalog.usesOpenAIReasoning(model)
        if openaiReasoning {
            body["max_completion_tokens"] = thinking ? max(maxTokens, 8192) : max(maxTokens, 2048)
            body["reasoning_effort"] = thinking ? "medium" : "none"
        } else {
            body["temperature"] = temperature
            body["max_tokens"] = thinking ? max(maxTokens, 8192) : maxTokens
            let payload = provider?.thinkingPayload ?? .none
            switch payload {
            case .typeObject:
                body["thinking"] = ["type": thinking ? "enabled" : "disabled"]
                if thinking { body["reasoning_effort"] = "high" }
            case .none:
                if thinking, provider == .custom {
                    body["thinking"] = ["type": "enabled"]
                }
            }
        }
        if stream {
            body["stream"] = true
            let assembled = try await postSSE(
                url: url,
                body: body,
                headers: ["Authorization": "Bearer \(key)"],
                timeout: thinking ? 90 : 60,
                onDelta: onDelta
            )
            if assembled.isEmpty { throw EnhanceError.emptyResponse }
            return assembled
        }
        let json = try await postJSON(
            url: url,
            body: body,
            headers: ["Authorization": "Bearer \(key)"],
            timeout: thinking ? 90 : 60
        )
        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any] {
            if let content = message["content"] as? String, !content.isEmpty {
                return content
            }
            if let parts = message["content"] as? [[String: Any]] {
                let text = parts.compactMap { $0["text"] as? String }.joined()
                if !text.isEmpty { return text }
            }
        }
        throw EnhanceError.emptyResponse
    }

    private static func postSSE(
        url: URL,
        body: [String: Any],
        headers: [String: String],
        timeout: TimeInterval,
        onDelta: (@Sendable (String) -> Void)?
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await urlSession.bytes(for: request)
        } catch {
            throw mapTransport(error)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 0 { throw EnhanceError.network("") }
        if !(200...299).contains(code) {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
            }
            throw EnhanceError.http(code, errorDetail(from: data))
        }
        var assembled = ""
        var truncated = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if let piece = SSEChatParser.content(fromLine: line) {
                assembled += piece
                onDelta?(piece)
            }
            if SSEChatParser.finishReason(fromLine: line) == "length" {
                truncated = true
            }
        }
        if truncated {
            NSLog("[uyiprompt] model output hit max_tokens; result may be truncated")
        }
        return assembled
    }

    private static func postJSON(
        url: URL,
        body: [String: Any],
        headers: [String: String],
        timeout: TimeInterval = 60
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw mapTransport(error)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 0 {
            throw EnhanceError.network("")
        }
        if !(200...299).contains(code) {
            throw EnhanceError.http(code, errorDetail(from: data))
        }
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }
}
