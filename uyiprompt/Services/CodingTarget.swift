import Foundation

/// Maps a frontmost Mac app to a coding-tool prompt hint, matching PromptDC `coding-target.js`.
enum CodingTarget {
    static let bundleKeys: [String: String] = [
        "com.todesktop.230313mzl4w4u92": "cursor",
        "com.anthropic.claudefordesktop": "claude",
        "com.openai.codex": "codex",
        "com.microsoft.VSCode": "copilot",
        "com.microsoft.VSCodeInsiders": "copilot",
        "com.exafunction.windsurf": "windsurf",
        "com.trae.app": "trae",
        "dev.zed.Zed": "default",
        "com.google.antigravity": "antigravity",
    ]

    static func key(for bundleID: String?) -> String? {
        guard let bundleID else { return nil }
        return bundleKeys[bundleID]
    }

    static func extraPrompt(for bundleID: String?) -> String? {
        guard let key = key(for: bundleID) else { return nil }
        if key == "default" {
            return "The user is writing a coding prompt in a developer tool. Structure it for an AI coding assistant."
        }
        return "The user is writing in \(key). Tailor the rewritten prompt for that coding tool."
    }
}
