import AppKit
import Foundation

struct CaptureSession {
    var originalText: String
    var bundleID: String?
    var profileID: String
    var enhancedText: String
    var job: SelectionJob
    var translateLanguage: TranslateLanguage
}

/// Shortcut → capture → enhance → popover → replace.
/// Mirrors Electron `enhanceSelection` in main.js.
@MainActor
final class EnhanceCoordinator {
    private weak var windows: AppWindows?
    private var session: AppSession?
    private var capture: CaptureSession?
    private var task: Task<Void, Never>?
    private var generation = 0

    func attach(session: AppSession, windows: AppWindows) {
        self.session = session
        self.windows = windows
    }

    func enhanceSelection() {
        start(job: .enhance)
    }

    func translateSelection() {
        start(job: .translate)
    }

    private func start(job: SelectionJob) {
        guard let session, let windows else { return }
        if windows.isOnboardingVisible {
            windows.showOnboarding()
            return
        }
        if !session.llm.isReady {
            windows.showPopover(
                state: .error(
                    EnhanceError.missingAPIKey.errorDescription ?? "还没有填 API Key",
                    profile: job == .translate ? "翻译" : session.currentProfile.name,
                    job: job,
                    translateLanguage: session.translateLanguage
                ),
                near: NSEvent.mouseLocation
            )
            return
        }

        generation += 1
        let gen = generation
        task?.cancel()
        let anchor = NSEvent.mouseLocation

        task = Task { [weak self] in
            await self?.run(generation: gen, job: job, session: session, windows: windows, anchor: anchor)
        }
    }

    func retry() {
        guard let capture else { return }
        runWork(on: capture)
    }

    func switchProfile(_ profileID: String) {
        guard var capture, capture.job == .enhance else { return }
        capture.profileID = profileID
        session?.currentProfileID = profileID
        self.capture = capture
        runWork(on: capture)
    }

    func switchTranslateLanguage(_ language: TranslateLanguage) {
        guard var capture, capture.job == .translate else { return }
        capture.translateLanguage = language
        session?.translateLanguage = language
        self.capture = capture
        runWork(on: capture)
    }

    func copyResult() {
        guard let text = capture?.enhancedText, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func replace() {
        guard let capture, !capture.enhancedText.isEmpty else { return }
        windows?.hidePopover()
        let text = capture.enhancedText
        let bundleID = capture.bundleID
        Task {
            let result = await SelectionService.paste(text, into: bundleID)
            if result.accessibilityDenied {
                windows?.showPopover(
                    state: .error(
                        "还写不回去：辅助功能对不上当前程序。可以先点「复制」。",
                        profile: label(for: capture),
                        original: capture.originalText,
                        job: capture.job,
                        translateLanguage: capture.translateLanguage
                    ),
                    near: NSEvent.mouseLocation
                )
                SelectionService.requestAccess()
            } else if !result.ok {
                windows?.showPopover(
                    state: .error(
                        result.error ?? "没能粘贴回去",
                        profile: label(for: capture),
                        original: capture.originalText,
                        job: capture.job,
                        translateLanguage: capture.translateLanguage
                    ),
                    near: NSEvent.mouseLocation
                )
            }
        }
    }

    private func run(generation gen: Int, job: SelectionJob, session: AppSession, windows: AppWindows, anchor: NSPoint) async {
        let fallbackName = job == .translate ? "翻译" : session.currentProfile.name
        if !SelectionService.isTrusted {
            SelectionService.promptForAccessibility()
            windows.showPopover(
                state: .error(
                    SelectionService.accessDeniedMessage,
                    profile: fallbackName,
                    job: job,
                    translateLanguage: session.translateLanguage
                ),
                near: anchor
            )
            return
        }

        let front = SelectionService.frontmostBundleID()
        if SelectionService.isOwnApp(front) {
            if let capture, !capture.originalText.isEmpty {
                windows.showPopover(state: state(from: capture, session: session, status: .ready), near: anchor)
            } else {
                windows.showPopover(
                    state: .error("请先在别的软件里选中文字", profile: fallbackName, job: job, translateLanguage: session.translateLanguage),
                    near: anchor
                )
            }
            return
        }

        let captured = await SelectionService.readSelection(preferredBundleID: front)
        guard gen == generation else { return }

        if captured.accessibilityDenied {
            SelectionService.promptForAccessibility()
            windows.showPopover(
                state: .error(
                    SelectionService.accessDeniedMessage,
                    profile: fallbackName,
                    job: job,
                    translateLanguage: session.translateLanguage
                ),
                near: anchor
            )
            return
        }

        let text = captured.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            windows.showPopover(
                state: .error("没读到选中的文字，再选一次试试", profile: fallbackName, job: job, translateLanguage: session.translateLanguage),
                near: anchor
            )
            return
        }

        let profile = session.profile(forBundleID: captured.bundleID)
        if job == .enhance {
            session.currentProfileID = profile.id
        }
        let stored = CaptureSession(
            originalText: text,
            bundleID: captured.bundleID,
            profileID: profile.id,
            enhancedText: "",
            job: job,
            translateLanguage: session.translateLanguage
        )
        capture = stored

        if job == .enhance, !session.enhancePopoverEnabled {
            await requestWork(generation: gen, session: session, windows: windows, capture: stored, anchor: anchor, silent: true)
            return
        }

        if job == .enhance, !session.autoEnhanceOnShortcut {
            windows.showPopover(state: state(from: stored, session: session, status: .ready), near: anchor)
            return
        }

        windows.showPopover(state: state(from: stored, session: session, status: .loading), near: anchor)
        await requestWork(generation: gen, session: session, windows: windows, capture: stored, anchor: anchor, silent: false)
    }

    private func runWork(on capture: CaptureSession) {
        guard let session, let windows else { return }
        generation += 1
        let gen = generation
        var next = capture
        if next.job == .enhance {
            let profile = session.profiles.first(where: { $0.id == next.profileID }) ?? session.currentProfile
            next.profileID = profile.id
        }
        next.enhancedText = ""
        self.capture = next
        let anchor = NSEvent.mouseLocation
        windows.showPopover(state: state(from: next, session: session, status: .loading), near: anchor)
        task?.cancel()
        task = Task { [weak self] in
            await self?.requestWork(generation: gen, session: session, windows: windows, capture: next, anchor: anchor, silent: false)
        }
    }

    private func requestWork(
        generation gen: Int,
        session: AppSession,
        windows: AppWindows,
        capture: CaptureSession,
        anchor: NSPoint,
        silent: Bool
    ) async {
        let profile = session.profiles.first(where: { $0.id == capture.profileID }) ?? session.currentProfile
        do {
            let result: String
            switch capture.job {
            case .enhance:
                let coding = profile.id == "code" ? CodingTarget.extraPrompt(for: capture.bundleID) : nil
                result = try await EnhanceService.enhance(
                    message: capture.originalText,
                    profilePrompt: profile.systemPrompt,
                    settings: session.llm,
                    language: session.enhanceLanguage,
                    codingTarget: coding
                )
            case .translate:
                result = try await EnhanceService.translate(
                    message: capture.originalText,
                    settings: session.llm,
                    language: capture.translateLanguage
                )
            }
            guard gen == generation else { return }
            var stored = capture
            stored.enhancedText = result
            self.capture = stored
            if silent {
                let paste = await SelectionService.paste(result, into: capture.bundleID)
                if !paste.ok {
                    windows.showPopover(
                        state: .error(
                            paste.error ?? "没能粘贴回去",
                            profile: label(for: stored, session: session),
                            profileId: stored.profileID,
                            original: stored.originalText,
                            job: stored.job,
                            translateLanguage: stored.translateLanguage
                        ),
                        near: anchor
                    )
                }
                return
            }
            windows.showPopover(state: state(from: stored, session: session, status: .ready), near: anchor)
        } catch {
            guard gen == generation else { return }
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            windows.showPopover(
                state: .error(
                    message,
                    profile: label(for: capture, session: session),
                    profileId: capture.profileID,
                    original: capture.originalText,
                    job: capture.job,
                    translateLanguage: capture.translateLanguage
                ),
                near: anchor
            )
        }
    }

    private func label(for capture: CaptureSession, session: AppSession? = nil) -> String {
        if capture.job == .translate { return "翻译" }
        let session = session ?? self.session
        return session?.profiles.first(where: { $0.id == capture.profileID })?.name
            ?? session?.currentProfile.name
            ?? "校对"
    }

    private func state(from capture: CaptureSession, session: AppSession, status: PopoverContentState.Status) -> PopoverContentState {
        let profile = session.profiles.first(where: { $0.id == capture.profileID }) ?? session.currentProfile
        return PopoverContentState(
            status: status,
            profileId: capture.profileID,
            profileName: capture.job == .translate ? "翻译" : profile.name,
            originalText: capture.originalText,
            enhancedText: capture.enhancedText,
            error: "",
            job: capture.job,
            translateLanguage: capture.translateLanguage
        )
    }
}

extension PopoverContentState {
    static func error(
        _ message: String,
        profile: String,
        profileId: String = "",
        original: String = "",
        job: SelectionJob = .enhance,
        translateLanguage: TranslateLanguage = .auto
    ) -> PopoverContentState {
        PopoverContentState(
            status: .error,
            profileId: profileId,
            profileName: profile,
            originalText: original,
            enhancedText: "",
            error: message,
            job: job,
            translateLanguage: translateLanguage
        )
    }
}
