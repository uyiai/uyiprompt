import Foundation

struct WritingProfile: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var systemPrompt: String
    var builtin: Bool

    static let builtins: [WritingProfile] = [
        .init(id: "grammar", name: "校对", systemPrompt: "修正语法、拼写和标点，保留作者语气、时态和原文语言。不要额外加称呼或结尾。", builtin: true),
        .init(id: "email", name: "写邮件", systemPrompt: "改写成结构清晰的邮件，保留原文语言、人名和事实。", builtin: true),
        .init(id: "social", name: "发帖", systemPrompt: "改写成适合社交平台的短文，标签、@ 和链接保持原样。", builtin: true),
        .init(id: "image-prompt", name: "生图提示", systemPrompt: "改写成详细的图像生成提示：主体、场景、光线、风格、构图。保留用户给的限制。", builtin: true),
        .init(id: "summarize", name: "总结", systemPrompt: "概括选中内容，保留关键事实、人名和数字，使用原文语言。", builtin: true),
        .init(id: "reply", name: "写回复", systemPrompt: "用同样的语言和自然语气写一封回复。", builtin: true),
        .init(id: "professional", name: "更正式", systemPrompt: "改写成专业、简洁的语气，保留原意和原文语言。", builtin: true),
        .init(id: "concise", name: "更短", systemPrompt: "在不丢失意思的前提下写得更短，保留原文语言。", builtin: true),
        .init(id: "explain", name: "讲人话", systemPrompt: "改写成更容易理解的说法，保留原文语言。", builtin: true),
        .init(id: "code", name: "编程提示", systemPrompt: "改写成给 AI 编程助手的清晰、有结构的提示，代码标识符保持原样。", builtin: true),
    ]

    /// Older English / first-pass Chinese titles we replace on load.
    static let previousNames: [String: Set<String>] = [
        "grammar": ["Grammar", "语法"],
        "email": ["Email", "邮件"],
        "social": ["Social", "社交"],
        "image-prompt": ["Image prompt", "Image Prompt", "绘画提示"],
        "summarize": ["Summarize", "摘要"],
        "reply": ["Reply", "回复"],
        "professional": ["Professional", "正式"],
        "concise": ["Concise", "精简"],
        "explain": ["Explain", "讲清楚"],
        "code": ["Code", "编程"],
    ]
}

@MainActor
final class AppSession: ObservableObject {
    enum AppearancePreference: String, CaseIterable, Identifiable, Codable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "跟随系统"
            case .light: "浅色"
            case .dark: "深色"
            }
        }
    }

    @Published var appearance: AppearancePreference = .system { didSet { persistSoon() } }
    @Published var showDockIcon = false { didSet { persistSoon() } }
    @Published var panelPinned = true { didSet { persistSoon() } }
    @Published var enhancePopoverEnabled = true { didSet { persistSoon() } }
    @Published var autoEnhanceOnShortcut = true { didSet { persistSoon() } }
    @Published var selectionActionBarEnabled = true { didSet { persistSoon() } }
    @Published var onboardingCompleted = false { didSet { persistSoon() } }
    @Published var profiles: [WritingProfile] = WritingProfile.builtins { didSet { persistSoon() } }
    @Published var currentProfileID = WritingProfile.builtins[0].id { didSet { persistSoon() } }
    @Published var llm = LLMSettings.empty { didSet { persistSoon() } }
    @Published var enhanceLanguage: EnhanceLanguage = .auto { didSet { persistSoon() } }
    @Published var translateLanguage: TranslateLanguage = .auto { didSet { persistSoon() } }
    @Published var appProfileRules: [String: String] = [:] { didSet { persistSoon() } }
    private var isLoading = true

    enum EnhanceLanguage: String, CaseIterable, Identifiable, Codable {
        case auto, english, chinese, spanish, portuguese, korean, indian, russian, vietnamese, czech

        var id: String { rawValue }

        var title: String {
            switch self {
            case .auto: "自动（保持原文语言）"
            case .english: "英语"
            case .chinese: "中文"
            case .spanish: "西班牙语"
            case .portuguese: "葡萄牙语"
            case .korean: "韩语"
            case .indian: "印地语"
            case .russian: "俄语"
            case .vietnamese: "越南语"
            case .czech: "捷克语"
            }
        }
    }

    func profile(forBundleID bundleID: String?) -> WritingProfile {
        if let bundleID, let id = appProfileRules[bundleID],
           let profile = profiles.first(where: { $0.id == id }) {
            return profile
        }
        return currentProfile
    }

    var currentProfile: WritingProfile {
        profiles.first(where: { $0.id == currentProfileID }) ?? WritingProfile.builtins[0]
    }

    func addCustomProfile() {
        let profile = WritingProfile(
            id: "custom-\(UUID().uuidString)",
            name: "新风格",
            systemPrompt: "按用户意图改写这段文字，保留原文语言和关键事实。",
            builtin: false
        )
        profiles.append(profile)
        currentProfileID = profile.id
    }

    func deleteProfile(_ profile: WritingProfile) {
        guard !profile.builtin else { return }
        profiles.removeAll { $0.id == profile.id }
        if profiles.isEmpty {
            profiles = WritingProfile.builtins
        }
        if !profiles.contains(where: { $0.id == currentProfileID }) {
            currentProfileID = profiles[0].id
        }
    }

    private var persistTask: Task<Void, Never>?

    init() {
        load()
        isLoading = false
        migrateBuiltinNames()
        migrateRetiredModels()
    }

    private func migrateRetiredModels() {
        var next = llm
        next.migrateRetiredModels()
        if next != llm {
            llm = next
        }
    }

    private func migrateBuiltinNames() {
        let fresh = Dictionary(uniqueKeysWithValues: WritingProfile.builtins.map { ($0.id, $0) })
        var changed = false
        let next = profiles.map { profile -> WritingProfile in
            guard profile.builtin, let updated = fresh[profile.id] else { return profile }
            var copy = profile
            let stale = WritingProfile.previousNames[profile.id] ?? []
            if stale.contains(profile.name) {
                copy.name = updated.name
                changed = true
            }
            if looksEnglish(profile.systemPrompt), copy.systemPrompt != updated.systemPrompt {
                copy.systemPrompt = updated.systemPrompt
                changed = true
            }
            return copy
        }
        if changed {
            profiles = next
        }
    }

    private func looksEnglish(_ text: String) -> Bool {
        let sample = text.prefix(80)
        let letters = sample.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        let ascii = letters.filter(\.isASCII)
        return Double(ascii.count) / Double(letters.count) > 0.85
    }

    func saveNow() {
        persistTask?.cancel()
        write()
    }

    private func persistSoon() {
        guard !isLoading else { return }
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.write()
        }
    }

    private struct Snapshot: Codable {
        var appearance: AppearancePreference
        var showDockIcon: Bool
        var panelPinned: Bool
        var enhancePopoverEnabled: Bool
        var autoEnhanceOnShortcut: Bool
        var selectionActionBarEnabled: Bool?
        var onboardingCompleted: Bool
        var profiles: [WritingProfile]
        var currentProfileID: String
        var llm: LLMSettings
        var enhanceLanguage: EnhanceLanguage?
        var translateLanguage: TranslateLanguage?
        var appProfileRules: [String: String]?
    }

    private func load() {
        let url = Self.fileURL
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }
        appearance = snapshot.appearance
        showDockIcon = snapshot.showDockIcon
        panelPinned = snapshot.panelPinned
        enhancePopoverEnabled = snapshot.enhancePopoverEnabled
        autoEnhanceOnShortcut = snapshot.autoEnhanceOnShortcut
        selectionActionBarEnabled = snapshot.selectionActionBarEnabled ?? true
        onboardingCompleted = snapshot.onboardingCompleted
        profiles = snapshot.profiles.isEmpty ? WritingProfile.builtins : snapshot.profiles
        currentProfileID = snapshot.currentProfileID
        llm = snapshot.llm
        enhanceLanguage = snapshot.enhanceLanguage ?? .auto
        translateLanguage = snapshot.translateLanguage ?? .auto
        appProfileRules = snapshot.appProfileRules ?? [:]
    }

    private func write() {
        let snapshot = Snapshot(
            appearance: appearance,
            showDockIcon: showDockIcon,
            panelPinned: panelPinned,
            enhancePopoverEnabled: enhancePopoverEnabled,
            autoEnhanceOnShortcut: autoEnhanceOnShortcut,
            selectionActionBarEnabled: selectionActionBarEnabled,
            onboardingCompleted: onboardingCompleted,
            profiles: profiles,
            currentProfileID: currentProfileID,
            llm: llm,
            enhanceLanguage: enhanceLanguage,
            translateLanguage: translateLanguage,
            appProfileRules: appProfileRules
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            let tmp = Self.fileURL.appendingPathExtension("tmp")
            try data.write(to: tmp, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
            if FileManager.default.fileExists(atPath: Self.fileURL.path) {
                try FileManager.default.removeItem(at: Self.fileURL)
            }
            try FileManager.default.moveItem(at: tmp, to: Self.fileURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.fileURL.path)
        } catch {
            NSLog("[uyiprompt] settings write failed: %@", error.localizedDescription)
        }
    }

    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("uyiprompt", isDirectory: true)
    }

    private static var fileURL: URL {
        directory.appendingPathComponent("settings.json")
    }
}
