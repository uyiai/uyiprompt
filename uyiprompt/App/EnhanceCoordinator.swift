import AppKit
import Foundation

struct CaptureSession {
    var originalText: String
    var bundleID: String?
    var profileID: String
    var enhancedText: String
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
        guard let session, let windows else { return }
        if windows.isOnboardingVisible {
            windows.showOnboarding()
            return
        }
        if !session.llm.isReady {
            windows.showPopover(
                state: .error(
                    EnhanceError.missingAPIKey.errorDescription ?? "还没有填 API Key",
                    profile: session.currentProfile.name
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
            await self?.run(generation: gen, session: session, windows: windows, anchor: anchor)
        }
    }

    func retry() {
        guard let capture else { return }
        runEnhance(on: capture, profileID: capture.profileID)
    }

    func switchProfile(_ profileID: String) {
        guard var capture else { return }
        capture.profileID = profileID
        session?.currentProfileID = profileID
        self.capture = capture
        runEnhance(on: capture, profileID: profileID)
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
                        "还需要辅助功能才能把改写写回去。可以先点「复制」。",
                        profile: session?.currentProfile.name ?? "语法"
                    ),
                    near: NSEvent.mouseLocation
                )
                SelectionService.promptForAccessibility()
            } else if !result.ok {
                windows?.showPopover(
                    state: .error(result.error ?? "没能粘贴回去", profile: session?.currentProfile.name ?? "语法"),
                    near: NSEvent.mouseLocation
                )
            }
        }
    }

    private func run(generation gen: Int, session: AppSession, windows: AppWindows, anchor: NSPoint) async {
        if !SelectionService.isTrusted {
            SelectionService.promptForAccessibility()
            windows.showPopover(
                state: .error(
                    "需要辅助功能才能读取选中的文字。请在系统设置 → 隐私与安全性 → 辅助功能里打开 uyiprompt。",
                    profile: session.currentProfile.name
                ),
                near: anchor
            )
            return
        }

        let front = SelectionService.frontmostBundleID()
        if SelectionService.isOwnApp(front) {
            if let capture, !capture.originalText.isEmpty {
                windows.showPopover(
                    state: PopoverContentState(
                        status: capture.enhancedText.isEmpty ? .ready : .ready,
                        profileId: capture.profileID,
                        profileName: session.currentProfile.name,
                        originalText: capture.originalText,
                        enhancedText: capture.enhancedText,
                        error: ""
                    ),
                    near: anchor
                )
            } else {
                windows.showPopover(
                    state: .error("请先在别的软件里选中文字", profile: session.currentProfile.name),
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
                    "需要辅助功能才能读取选中的文字。请在系统设置 → 隐私与安全性 → 辅助功能里打开 uyiprompt。",
                    profile: session.currentProfile.name
                ),
                near: anchor
            )
            return
        }

        let text = captured.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            windows.showPopover(
                state: .error("没读到选中的文字，再选一次试试", profile: session.currentProfile.name),
                near: anchor
            )
            return
        }

        let profile = session.profile(forBundleID: captured.bundleID)
        session.currentProfileID = profile.id
        let stored = CaptureSession(originalText: text, bundleID: captured.bundleID, profileID: profile.id, enhancedText: "")
        capture = stored

        if !session.enhancePopoverEnabled {
            await requestEnhance(generation: gen, session: session, windows: windows, capture: stored, profile: profile, anchor: anchor, silent: true)
            return
        }

        if !session.autoEnhanceOnShortcut {
            windows.showPopover(
                state: PopoverContentState(
                    status: .ready,
                    profileId: profile.id,
                    profileName: profile.name,
                    originalText: text,
                    enhancedText: "",
                    error: ""
                ),
                near: anchor
            )
            return
        }

        windows.showPopover(
            state: PopoverContentState(
                status: .loading,
                profileId: profile.id,
                profileName: profile.name,
                originalText: text,
                enhancedText: "",
                error: ""
            ),
            near: anchor
        )
        await requestEnhance(generation: gen, session: session, windows: windows, capture: stored, profile: profile, anchor: anchor, silent: false)
    }

    private func runEnhance(on capture: CaptureSession, profileID: String) {
        guard let session, let windows else { return }
        generation += 1
        let gen = generation
        let profile = session.profiles.first(where: { $0.id == profileID }) ?? session.currentProfile
        var next = capture
        next.profileID = profile.id
        next.enhancedText = ""
        self.capture = next
        let anchor = NSEvent.mouseLocation
        windows.showPopover(
            state: PopoverContentState(
                status: .loading,
                profileId: profile.id,
                profileName: profile.name,
                originalText: next.originalText,
                enhancedText: "",
                error: ""
            ),
            near: anchor
        )
        task?.cancel()
        task = Task { [weak self] in
            await self?.requestEnhance(generation: gen, session: session, windows: windows, capture: next, profile: profile, anchor: anchor, silent: false)
        }
    }

    private func requestEnhance(
        generation gen: Int,
        session: AppSession,
        windows: AppWindows,
        capture: CaptureSession,
        profile: WritingProfile,
        anchor: NSPoint,
        silent: Bool
    ) async {
        do {
            let coding = profile.id == "code" ? CodingTarget.extraPrompt(for: capture.bundleID) : nil
            let result = try await EnhanceService.enhance(
                message: capture.originalText,
                profilePrompt: profile.systemPrompt,
                settings: session.llm,
                language: session.enhanceLanguage,
                codingTarget: coding
            )
            guard gen == generation else { return }
            var stored = capture
            stored.enhancedText = result
            stored.profileID = profile.id
            self.capture = stored
            if silent {
                let paste = await SelectionService.paste(result, into: capture.bundleID)
                if !paste.ok {
                    windows.showPopover(
                        state: .error(paste.error ?? "没能粘贴回去", profile: profile.name, profileId: profile.id, original: capture.originalText),
                        near: anchor
                    )
                }
                return
            }
            windows.showPopover(
                state: PopoverContentState(
                    status: .ready,
                    profileId: profile.id,
                    profileName: profile.name,
                    originalText: capture.originalText,
                    enhancedText: result,
                    error: ""
                ),
                near: anchor
            )
        } catch {
            guard gen == generation else { return }
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            windows.showPopover(
                state: .error(message, profile: profile.name, profileId: profile.id, original: capture.originalText),
                near: anchor
            )
        }
    }
}

extension PopoverContentState {
    static func error(_ message: String, profile: String, profileId: String = "", original: String = "") -> PopoverContentState {
        PopoverContentState(
            status: .error,
            profileId: profileId,
            profileName: profile,
            originalText: original,
            enhancedText: "",
            error: message
        )
    }
}
