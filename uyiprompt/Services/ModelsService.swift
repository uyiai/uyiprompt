import Foundation

/// Fetches `/v1/models` from an OpenAI-compatible endpoint so the user can
/// pick a model instead of typing its id. The key is optional — local
/// servers like Ollama and LM Studio accept unauthenticated requests.
enum ModelsService {
    static func listModels(baseURL: String, key: String) async throws -> [String] {
        let url = try OpenAICompatibleEndpoint.modelsURL(from: baseURL)
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        } catch {
            throw EnhanceService.mapTransport(error)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200...299).contains(code) {
            throw EnhanceError.http(code, String(String(data: data, encoding: .utf8) ?? "").prefix(200).description)
        }
        return parse(data)
    }

    /// Accepts `{"data":[{"id":...}]}` (OpenAI style) and a bare `[{"id":...}]` array.
    static func parse(_ data: Data) -> [String] {
        let object = try? JSONSerialization.jsonObject(with: data)
        let rows: [[String: Any]]
        if let dict = object as? [String: Any], let list = dict["data"] as? [[String: Any]] {
            rows = list
        } else if let list = object as? [[String: Any]] {
            rows = list
        } else {
            return []
        }
        let ids = rows.compactMap { $0["id"] as? String }.filter { !$0.isEmpty }
        return Array(NSOrderedSet(array: ids.sorted())) as? [String] ?? ids.sorted()
    }
}
