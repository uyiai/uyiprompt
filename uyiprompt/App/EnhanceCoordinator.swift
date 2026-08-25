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

    func runCaptured(text: String, bundleID: String?, job: SelectionJob, near point: NSPoint) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            start(job: job)
            return
        }
        start(job: job, prefilledText: trimmed, bundleID: bundleID, anchor: point)
    }

    private func start(job: SelectionJob, prefilledText: String? = nil, bundleID: String? = nil, anchor: NSPoint = NSEvent.mouseLocation) {
        guard let session, let windows else { return }
        if windows.isOnboardingVisible {
            windows.showOnboarding()
            return
        }
        windows.hideActionBar()
        if !session.llm.isReady {
            windows.showPopover(
                state: .error(
                    EnhanceError.missingAPIKey.errorDescription ?? L10n.t("error.missingKey"),
                    profile: job == .translate ? L10n.t("job.translate") : session.currentProfile.localizedName,
                    job: job,
                    translateLanguage: session.translateLanguage
                ),
                near: anchor
            )
            return
        }

        generation += 1
        let gen = generation
        task?.cancel()

        task = Task { [weak self] in
            await self?.run(
                generation: gen,
                job: job,
                session: session,
                windows: windows,
                anchor: anchor,
                prefilledText: prefilledText,
                bundleID: bundleID
            )
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
                        L10n.t("error.pasteAccess"),
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
                        result.error ?? L10n.t("error.pasteFail"),
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

    private func run(
        generation gen: Int,
        job: SelectionJob,
        session: AppSession,
        windows: AppWindows,
        anchor: NSPoint,
        prefilledText: String? = nil,
        bundleID: String? = nil
    ) async {
        let fallbackName = job == .translate ? L10n.t("job.translate") : session.currentProfile.localizedName
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

        let captured: SelectionCapture
        if let prefilledText, !prefilledText.isEmpty {
            captured = SelectionCapture(
                text: prefilledText,
                bundleID: bundleID ?? SelectionService.frontmostBundleID(),
                usedClipboardFallback: false,
                accessibilityDenied: false
            )
        } else {
            let front = SelectionService.frontmostBundleID()
            if SelectionService.isOwnApp(front) {
                if let capture, !capture.originalText.isEmpty {
                    windows.showPopover(state: state(from: capture, session: session, status: .ready), near: anchor)
                } else {
                    windows.showPopover(
                        state: .error(L10n.t("error.selectOther"), profile: fallbackName, job: job, translateLanguage: session.translateLanguage),
                        near: anchor
                    )
                }
                return
            }

            captured = await SelectionService.readSelection(preferredBundleID: front)
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
        }

        let text = captured.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            windows.showPopover(
                state: .error(L10n.t("error.noSelection"), profile: fallbackName, job: job, translateLanguage: session.translateLanguage),
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
        do {
            let result = try await RewritePipeline.transform(
                message: capture.originalText,
                job: capture.job,
                session: session,
                bundleID: capture.bundleID,
                profileID: capture.profileID
            )
            guard gen == generation else { return }
            var stored = capture
            stored.enhancedText = result
            self.capture = stored
            if silent {
                let paste = await SelectionService.paste(result, into: capture.bundleID)
                if !paste.ok {
                    windows.showPopover(
                        state: .error(
                            paste.error ?? L10n.t("error.pasteFail"),
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
        if capture.job == .translate { return L10n.t("job.translate") }
        let session = session ?? self.session
        return session?.profiles.first(where: { $0.id == capture.profileID })?.localizedName
            ?? session?.currentProfile.localizedName
            ?? L10n.t("profile.grammar")
    }

    private func state(from capture: CaptureSession, session: AppSession, status: PopoverContentState.Status) -> PopoverContentState {
        let profile = session.profiles.first(where: { $0.id == capture.profileID }) ?? session.currentProfile
        return PopoverContentState(
            status: status,
            profileId: capture.profileID,
            profileName: capture.job == .translate ? L10n.t("job.translate") : profile.localizedName,
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
