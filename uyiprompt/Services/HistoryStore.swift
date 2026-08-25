import Foundation

struct HistoryItem: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var createdAt: Date
    var job: SelectionJob
    var original: String
    var result: String
    var label: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        job: SelectionJob,
        original: String,
        result: String,
        label: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.job = job
        self.original = original
        self.result = result
        self.label = label
    }

    var preview: String {
        let text = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count <= 80 { return text }
        return String(text.prefix(80)) + "…"
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    static let cap = 20

    @Published private(set) var items: [HistoryItem] = []
    private let fileURL: URL

    init(fileURL: URL = HistoryStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data)
        else { return }
        items = Array(decoded.prefix(Self.cap))
    }

    func record(job: SelectionJob, original: String, result: String, label: String) {
        let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResult.isEmpty else { return }
        let item = HistoryItem(job: job, original: trimmedOriginal, result: trimmedResult, label: label)
        items.removeAll { $0.original == item.original && $0.result == item.result && $0.job == item.job }
        items.insert(item, at: 0)
        if items.count > Self.cap {
            items = Array(items.prefix(Self.cap))
        }
        save()
    }

    func remove(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let tmp = fileURL.appendingPathExtension("tmp")
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tmp, to: fileURL)
        } catch {
            NSLog("[uyiprompt] history write failed: %@", error.localizedDescription)
        }
    }

    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("uyiprompt", isDirectory: true)
    }

    static var defaultFileURL: URL {
        directory.appendingPathComponent("history.json")
    }
}