import Foundation

/// Single rewrite/translate entry used by the selection overlays and the draft panel.
enum RewritePipeline {
    @MainActor
    static func transform(
        message: String,
        job: SelectionJob,
        session: AppSession,
        bundleID: String? = nil,
        profileID: String? = nil
    ) async throws -> String {
        switch job {
        case .enhance:
            let profile = session.profiles.first(where: { $0.id == profileID })
                ?? session.profile(forBundleID: bundleID)
            let coding = profile.id == "code" ? CodingTarget.extraPrompt(for: bundleID) : nil
            return try await EnhanceService.enhance(
                message: message,
                profilePrompt: profile.systemPrompt,
                settings: session.llm,
                language: session.enhanceLanguage,
                codingTarget: coding
            )
        case .translate:
            return try await EnhanceService.translate(
                message: message,
                settings: session.llm,
                language: session.translateLanguage
            )
        }
    }
}
