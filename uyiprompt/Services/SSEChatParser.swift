import Foundation

/// Incremental parser for OpenAI-compatible `text/event-stream` chat chunks.
struct SSEChatParser {
    private var buffer = ""

    mutating func ingest(_ chunk: String) -> [String] {
        buffer += chunk
        var pieces: [String] = []
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            if let piece = Self.content(fromLine: line) {
                pieces.append(piece)
            }
        }
        return pieces
    }

    /// "length" means the model hit its output cap and the result is truncated.
    static func finishReason(fromLine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload.isEmpty || payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]]
        else { return nil }
        return choices.first?["finish_reason"] as? String
    }

    static func content(fromLine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload.isEmpty || payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]]
        else { return nil }
        if let delta = choices.first?["delta"] as? [String: Any],
           let content = delta["content"] as? String,
           !content.isEmpty {
            return content
        }
        if let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String,
           !content.isEmpty {
            return content
        }
        return nil
    }
}