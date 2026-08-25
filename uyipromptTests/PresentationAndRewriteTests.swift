import AppKit
import SwiftUI
import Testing
@testable import uyiprompt

@Suite("Overlay presentation")
struct OverlayPresentationTests {
    @Test func overlayPolicyPlanDoesNotActivateOrTakeKey() {
        let plan = WindowPresentation.plan(for: WindowPresentation.overlayPolicy)
        #expect(plan.activateApp == false)
        #expect(plan.makeKey == false)
        #expect(plan.orderFrontRegardless == true)
        #expect(WindowPresentation.overlayPolicy == .inactive)
    }

    @Test func productWindowPlanActivatesAndTakesKey() {
        let plan = WindowPresentation.plan(for: WindowPresentation.productWindowPolicy)
        #expect(plan.activateApp == true)
        #expect(plan.makeKey == true)
    }

    @Test @MainActor func shippedOverlayWindowsAreNonactivatingPanels() {
        let popover = ProductWindowFactory.makeEnhancePopover(size: WindowMetrics.popoverDefault)
        let bar = ProductWindowFactory.makeActionBar(size: WindowMetrics.actionBarSize)
        #expect(WindowPresentation.isNonactivatingOverlay(popover))
        #expect(WindowPresentation.isNonactivatingOverlay(bar))
        #expect(popover.styleMask.contains(.nonactivatingPanel))
        #expect(bar.styleMask.contains(.nonactivatingPanel))
    }

    @Test @MainActor func overlayShowDoesNotMakeKeyOrActivate() {
        let bar = ProductWindowFactory.makeActionBar(size: WindowMetrics.actionBarSize)
        let popover = ProductWindowFactory.makeEnhancePopover(size: WindowMetrics.popoverDefault)
        defer {
            bar.orderOut(nil)
            popover.orderOut(nil)
        }
        WindowPresentation.show(bar, policy: WindowPresentation.overlayPolicy)
        WindowPresentation.show(popover, policy: WindowPresentation.overlayPolicy)
        #expect(bar.isKeyWindow == false)
        #expect(popover.isKeyWindow == false)
        let plan = WindowPresentation.plan(for: WindowPresentation.overlayPolicy)
        #expect(plan.activateApp == false)
        #expect(plan.makeKey == false)
    }

    @Test @MainActor func overlayHostAcceptsFirstMouse() {
        let host = GlassHostingController(rootView: Text("chip"), firstMouse: true)
        let hosted = host.view.subviews.compactMap { $0 as? NSHostingView<Text> }.first
        #expect(hosted is FirstMouseHostingView<Text>)
        #expect(hosted?.acceptsFirstMouse(for: nil) == true)
    }
}

@Suite("Shared rewrite entry")
struct RewritePipelineTests {
    @Test @MainActor func actionChipAndDraftPanelShareRewritePipeline() async {
        let session = AppSession()
        let windows = AppWindows()
        windows.attach(session: session)
        defer { windows.invalidateSelectionWatcher() }

        await #expect(throws: EnhanceError.emptyInput) {
            try await RewritePipeline.transform(message: "   ", job: .enhance, session: session)
        }
        await #expect(throws: EnhanceError.emptyInput) {
            try await windows.rewriteDraft("   ", job: .enhance)
        }
        await #expect(throws: EnhanceError.emptyInput) {
            try await RewritePipeline.transform(message: "", job: .translate, session: session)
        }
        await #expect(throws: EnhanceError.emptyInput) {
            try await windows.rewriteDraft("", job: .translate)
        }
    }

    @Test @MainActor func selectionFallbackSeedsDraftPanel() {
        let session = AppSession()
        let windows = AppWindows()
        windows.attach(session: session)
        defer { windows.invalidateSelectionWatcher() }
        let seed = windows.seedPanel(draft: "hello panel", job: .translate)
        #expect(seed?.text == "hello panel")
        #expect(seed?.job == .translate)
        #expect(windows.panelSeed?.text == "hello panel")
        windows.consumePanelSeed()
        #expect(windows.panelSeed == nil)
        #expect(windows.seedPanel(draft: "   ", job: .enhance) == nil)
    }
}

@Suite("Secrets, stream parser, history")
struct StoreAndStreamTests {
    @Test func memorySecretsRoundTripAndJSONOmitsKeys() throws {
        let store = MemorySecretStore()
        store.set("sk-live", account: "deepseek")
        #expect(store.get(account: "deepseek") == "sk-live")
        var settings = LLMSettings.empty
        var deepseek = settings.endpoint(.deepseek)
        deepseek.key = "sk-live"
        settings.providers[.deepseek] = deepseek
        settings.saveSecrets(to: store)
        let encoded = try JSONEncoder().encode(settings)
        let json = String(data: encoded, encoding: .utf8) ?? ""
        #expect(!json.contains("sk-live"))
        var decoded = try JSONDecoder().decode(LLMSettings.self, from: encoded)
        decoded.loadSecrets(from: store)
        #expect(decoded.endpoint(.deepseek).key == "sk-live")
    }

    @Test func sseParserReadsDeltaContent() {
        #expect(SSEChatParser.content(fromLine: "data: [DONE]") == nil)
        let line = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#
        #expect(SSEChatParser.content(fromLine: line) == "Hello")
        var parser = SSEChatParser()
        let pieces = parser.ingest("data: {\"choices\":[{\"delta\":{\"content\":\"ab\"}}]}\nfoo\ndata: {\"choices\":[{\"delta\":{\"content\":\"c\"}}]}\n")
        #expect(pieces == ["ab", "c"])
    }

    @Test @MainActor func historyCapsAndDedupes() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("uyiprompt-history-test-\(UUID().uuidString).json")
        let store = HistoryStore(fileURL: url)
        defer { try? FileManager.default.removeItem(at: url) }
        for index in 1...25 {
            store.record(job: .enhance, original: "in\(index)", result: "out\(index)", label: "校对")
        }
        #expect(store.items.count == HistoryStore.cap)
        #expect(store.items.first?.original == "in25")
        store.record(job: .enhance, original: "in25", result: "out25", label: "校对")
        #expect(store.items.count == HistoryStore.cap)
        #expect(store.items.filter { $0.original == "in25" }.count == 1)
        store.clear()
        #expect(store.items.isEmpty)
    }
}

@Suite("Interface language", .serialized)
struct L10nTests {
    @Test func englishSwitchChangesVisibleCopy() {
        let previous = L10n.current
        defer { L10n.current = previous }
        L10n.sync(.english)
        #expect(L10n.t("job.enhance") == "Rewrite")
        #expect(L10n.t("job.translate") == "Translate")
        #expect(L10n.t("nav.providers") == "Models")
        L10n.sync(.chinese)
        #expect(L10n.t("job.enhance") == "改写")
        #expect(L10n.t("nav.general") == "通用")
    }

    @Test func systemChineseResolvesToChinese() {
        #expect(AppLanguage.chinese.resolved == .chinese)
        #expect(AppLanguage.english.resolved == .english)
    }
}

@Suite("Selection recovery")
struct SelectionRecoveryTests {
    @Test func emptySelectionErrorOffersPanel() {
        let state = PopoverContentState.error(
            "missing",
            profile: "校对",
            recovery: .emptySelection
        )
        #expect(state.recovery == .emptySelection)
        #expect(state.status == .error)
    }

    @Test func pasteFailureKeepsResultForPanel() {
        let state = PopoverContentState.error(
            "paste",
            profile: "校对",
            original: "src",
            enhanced: "dst",
            recovery: .pasteFailed
        )
        #expect(state.recovery == .pasteFailed)
        #expect(state.originalText == "src")
        #expect(state.enhancedText == "dst")
    }
}
