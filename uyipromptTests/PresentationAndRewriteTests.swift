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
        #expect(hosted?.isOpaque == false)
    }

    @Test @MainActor func actionBarHostHasNoGlassUnderlay() {
        let host = GlassHostingController(
            rootView: Text("chip"),
            material: nil,
            cornerRadius: WindowMetrics.actionBarSize.height / 2,
            firstMouse: true
        )
        _ = host.view
        #expect(!(host.view is NSVisualEffectView))
        #expect(host.view.layer?.cornerRadius == WindowMetrics.actionBarSize.height / 2)
        #expect(host.view.layer?.masksToBounds == true)
    }
}

@Suite("Action bar placement")
struct ActionBarPlacementTests {
    private let size = WindowMetrics.actionBarSize
    private let work = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let gap = WindowMetrics.actionBarGap
    private let chrome = WindowMetrics.actionBarNativeChromeHeight

    @Test func sitsBelowSelectionAndMissesNativeCopyBand() {
        let selection = NSRect(x: 400, y: 400, width: 160, height: 18)
        let cursor = NSPoint(x: selection.maxX, y: selection.midY)
        let frame = ActionBarPlacement.frame(
            selectionBounds: selection,
            cursor: cursor,
            size: size,
            workArea: work
        )
        let avoid = ActionBarPlacement.nativeChromeAvoidRect(around: selection)
        #expect(frame.maxY <= selection.minY - gap + 0.5)
        #expect(frame.intersects(selection) == false)
        #expect(frame.intersects(avoid) == false)
        #expect(frame.maxY < selection.maxY)
    }

    @Test func doesNotSitBesideSelectionWhereHostCopyChipsLand() {
        let selection = NSRect(x: 500, y: 360, width: 80, height: 20)
        let oldBeside = NSRect(
            x: selection.maxX + 20,
            y: selection.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        let frame = ActionBarPlacement.frame(
            selectionBounds: selection,
            cursor: NSPoint(x: selection.maxX, y: selection.midY),
            size: size,
            workArea: work
        )
        #expect(frame.intersects(oldBeside) == false)
        #expect(abs(frame.midY - selection.midY) > size.height / 2)
    }

    @Test func flipsAboveNativeChromeWhenThereIsNoRoomBelow() {
        let selection = NSRect(x: 200, y: 16, width: 140, height: 20)
        let frame = ActionBarPlacement.frame(
            selectionBounds: selection,
            cursor: NSPoint(x: selection.midX, y: selection.midY),
            size: size,
            workArea: work
        )
        let avoid = ActionBarPlacement.nativeChromeAvoidRect(around: selection)
        #expect(frame.minY >= selection.maxY + chrome + gap - 0.5)
        #expect(frame.intersects(avoid) == false)
        #expect(frame.intersects(selection) == false)
    }

    @Test func cursorOnlySitsBelowTheMouse() {
        let cursor = NSPoint(x: 640, y: 480)
        let frame = ActionBarPlacement.frame(
            selectionBounds: nil,
            cursor: cursor,
            size: size,
            workArea: work
        )
        #expect(frame.maxY <= cursor.y - gap + 0.5)
        #expect(frame.intersects(NSRect(x: cursor.x, y: cursor.y, width: 1, height: 1)) == false)
    }

    @Test func staysInsideTheWorkArea() {
        let selection = NSRect(x: 1320, y: 860, width: 100, height: 24)
        let frame = ActionBarPlacement.frame(
            selectionBounds: selection,
            cursor: NSPoint(x: 1410, y: 870),
            size: size,
            workArea: work
        )
        let inset = work.insetBy(dx: WindowMetrics.actionBarScreenInset, dy: WindowMetrics.actionBarScreenInset)
        #expect(inset.contains(frame))
    }

    @Test @MainActor func controllerForwardsExplicitWorkArea() {
        let selection = NSRect(x: 80, y: 200, width: 40, height: 16)
        let frame = ActionBarController.clampedFrame(
            anchor: NSPoint(x: 100, y: 208),
            size: size,
            selectionBounds: selection,
            workArea: work
        )
        #expect(frame.maxY <= selection.minY - gap + 0.5)
        #expect(frame.size == size)
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

    @Test func thinkTagsAndTruncationHelpers() {
        #expect(EnhanceService.stripThink("<think>plan</think>result") == "result")
        #expect(EnhanceService.stripThink("a<think>x</think>b<think>y</think>c") == "abc")
        #expect(EnhanceService.stripThink("<think>unclosed leak") == "unclosed leak")
        #expect(EnhanceService.scaledMaxTokens(forInputLength: 100) == 4096)
        #expect(EnhanceService.scaledMaxTokens(forInputLength: 50_000) == 16_384)
        #expect(EnhanceService.scaledMaxTokens(forInputLength: 100, floor: 8192) == 8192)
        let line = #"data: {"choices":[{"delta":{},"finish_reason":"length"}]}"#
        #expect(SSEChatParser.finishReason(fromLine: line) == "length")
        #expect(SSEChatParser.finishReason(fromLine: "data: [DONE]") == nil)
    }

    @Test func transportErrorsStayDiagnosable() {
        let timeout = EnhanceService.mapTransport(URLError(.timedOut))
        #expect(timeout as? EnhanceError == EnhanceError.network(L10n.t("error.timeout")))
        let offline = EnhanceService.mapTransport(URLError(.notConnectedToInternet))
        #expect(offline as? EnhanceError == EnhanceError.network(L10n.t("error.offline")))
        #expect(EnhanceService.mapTransport(CancellationError()) is CancellationError)
        #expect(EnhanceService.mapTransport(URLError(.cancelled)) is CancellationError)
    }

    @Test @MainActor func historyToggleStopsRecording() {
        let session = AppSession()
        let before = session.history.items.count
        let previous = session.historyEnabled
        defer { session.historyEnabled = previous }
        session.historyEnabled = false
        session.recordHistory(job: .enhance, original: "src", result: "dst", label: "校对")
        #expect(session.history.items.count == before)
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

@Suite("Local providers and style palette")
struct LocalProviderAndPaletteTests {
    @Test func localProvidersNeedNoKey() throws {
        #expect(LLMProvider.ollama.keyOptional)
        #expect(LLMProvider.lmstudio.keyOptional)
        #expect(!LLMProvider.deepseek.keyOptional)
        var settings = LLMSettings.empty
        settings.activeProvider = .ollama
        var endpoint = settings.endpoint(.ollama)
        endpoint.model = "qwen3"
        settings.providers[.ollama] = endpoint
        #expect(settings.isConfigured(.ollama))
        #expect(settings.isReady)
        let validated = try EnhanceService.validate(message: "hello", settings: settings)
        #expect(validated.key.isEmpty)
        #expect(validated.url.absoluteString == "http://localhost:11434/v1/chat/completions")
        #expect(LLMProvider.lmstudio.defaultBaseURL == "http://localhost:1234/v1")
    }

    @Test func cloudProvidersStillRequireKey() {
        var settings = LLMSettings.empty
        settings.activeProvider = .deepseek
        #expect(throws: EnhanceError.missingAPIKey) {
            _ = try EnhanceService.validate(message: "hello", settings: settings)
        }
    }

    @Test @MainActor func paletteStateIsPickStyleOnly() {
        let ready = PopoverContentState(
            status: .ready, profileId: "grammar", profileName: "校对",
            originalText: "src", enhancedText: "", error: "", job: .enhance
        )
        #expect(EnhancePopoverController.isPalette(ready))
        var done = ready
        done.enhancedText = "out"
        #expect(!EnhancePopoverController.isPalette(done))
        var translate = ready
        translate.job = .translate
        #expect(!EnhancePopoverController.isPalette(translate))
        var loading = ready
        loading.status = .loading
        #expect(!EnhancePopoverController.isPalette(loading))
    }
}

@Suite("Models endpoint")
struct ModelsServiceTests {
    @Test func modelsURLToleratesBaseURLShapes() throws {
        #expect(try OpenAICompatibleEndpoint.modelsURL(from: "https://api.deepseek.com/v1").absoluteString == "https://api.deepseek.com/v1/models")
        #expect(try OpenAICompatibleEndpoint.modelsURL(from: "https://api.example.com").absoluteString == "https://api.example.com/v1/models")
        #expect(try OpenAICompatibleEndpoint.modelsURL(from: "http://localhost:11434/v1/").absoluteString == "http://localhost:11434/v1/models")
    }

    @Test func parseReadsOpenAIAndBareArrays() {
        let openai = #"{"object":"list","data":[{"id":"b-model"},{"id":"a-model"},{"id":"a-model"}]}"#
        #expect(ModelsService.parse(Data(openai.utf8)) == ["a-model", "b-model"])
        let bare = #"[{"id":"m1"},{"name":"no-id"}]"#
        #expect(ModelsService.parse(Data(bare.utf8)) == ["m1"])
        #expect(ModelsService.parse(Data("not json".utf8)) == [])
    }
}

@Suite("Chat request body matrix")
struct ChatCompletionRequestTests {
    private func build(model: String, provider: LLMProvider?, thinking: Bool) -> ChatCompletionRequest {
        ChatCompletionRequest.build(
            model: model, system: "sys", user: "usr", maxTokens: 4096,
            provider: provider, thinking: thinking, temperature: 0.3, stream: true
        )
    }

    @Test func deepseekThinkingUsesTypeObjectPayload() {
        let request = build(model: "deepseek-v4-flash", provider: .deepseek, thinking: true)
        #expect(request.thinking == .init(type: "enabled"))
        #expect(request.reasoningEffort == "high")
        #expect(request.maxTokens == 8192)
        #expect(request.maxCompletionTokens == nil)
        #expect(request.stream == true)
    }

    @Test func deepseekWithoutThinkingDisablesPayload() {
        let request = build(model: "deepseek-v4-flash", provider: .deepseek, thinking: false)
        #expect(request.thinking == .init(type: "disabled"))
        #expect(request.reasoningEffort == nil)
        #expect(request.maxTokens == 4096)
        #expect(request.temperature == 0.3)
    }

    @Test func openAIReasoningModelsUseCompletionTokens() {
        let request = build(model: "gpt-5.6-luna", provider: .openai, thinking: false)
        #expect(request.maxCompletionTokens == 4096)
        #expect(request.reasoningEffort == "none")
        #expect(request.maxTokens == nil)
        #expect(request.temperature == nil)
        #expect(request.thinking == nil)
    }

    @Test func customProviderOnlySendsThinkingWhenEnabled() {
        #expect(build(model: "some-model", provider: .custom, thinking: false).thinking == nil)
        #expect(build(model: "some-model", provider: .custom, thinking: true).thinking == .init(type: "enabled"))
    }

    @Test func encodedBodyUsesWireKeys() throws {
        let data = try build(model: "deepseek-v4-flash", provider: .deepseek, thinking: true).encoded()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["max_tokens"] as? Int == 8192)
        #expect(json["reasoning_effort"] as? String == "high")
        #expect((json["thinking"] as? [String: Any])?["type"] as? String == "enabled")
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.first?["role"] as? String == "system")
    }
}

@Suite("Provider catalog and settings schema")
struct CatalogAndSchemaTests {
    @Test func pickerOmitsRetiredModels() {
        #expect(LLMProvider.deepseek.suggestedModels == ["deepseek-v4-flash", "deepseek-v4-pro"])
        #expect(LLMProvider.openai.suggestedModels == ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol"])
        #expect(!LLMProvider.deepseek.suggestedModels.contains("deepseek-chat"))
        #expect(LLMProvider.custom.suggestedModels.isEmpty)
        #expect(LLMProvider.custom.supportsThinkingToggle == false)
        #expect(LLMProvider.deepseek.thinkingPayload == .typeObject)
    }

    @Test func retiredModelsMigrateFromCatalog() {
        var settings = LLMSettings.empty
        var deepseek = settings.endpoint(.deepseek)
        deepseek.model = "deepseek-reasoner"
        settings.providers[.deepseek] = deepseek
        var openai = settings.endpoint(.openai)
        openai.model = "gpt-4o-mini"
        settings.providers[.openai] = openai
        settings.migrateRetiredModels()
        #expect(settings.endpoint(.deepseek).model == "deepseek-v4-flash")
        #expect(settings.endpoint(.deepseek).thinkingEnabled == true)
        #expect(settings.endpoint(.openai).model == "gpt-5.6-luna")
    }

    @Test @MainActor func oldSettingsJSONGetsSchemaVersion() throws {
        let json = """
        {
          "appearance": "system",
          "showDockIcon": false,
          "panelPinned": true,
          "enhancePopoverEnabled": true,
          "autoEnhanceOnShortcut": true,
          "onboardingCompleted": true,
          "profiles": [],
          "currentProfileID": "grammar",
          "llm": {
            "activeProvider": "deepseek",
            "providers": {
              "deepseek": {"key":"","model":"deepseek-chat","baseURL":"https://api.deepseek.com/v1"}
            }
          }
        }
        """
        let decoded = try JSONDecoder().decode(AppSession.Snapshot.self, from: Data(json.utf8))
        #expect(decoded.schemaVersion == nil)
        let migrated = AppSession.migrate(decoded)
        #expect(migrated.schemaVersion == SettingsSchema.current)
        #expect(migrated.llm.endpoint(.deepseek).model == "deepseek-v4-flash")
        #expect(migrated.llm.endpoint(.deepseek).thinkingEnabled == false)
        let encoded = try JSONEncoder().encode(migrated)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        #expect(object?["schemaVersion"] as? Int == SettingsSchema.current)
    }

    @Test func selectionFenceDropsLegacyAndCurrentMarkers() {
        let wrapped = EnhanceService.delimit("hello")
        #expect(wrapped.contains("UYIPROMPT_SELECTION"))
        #expect(!wrapped.contains("PROMPTDC"))
        #expect(SelectionFence.strip("\(SelectionFence.start)x\(SelectionFence.end)") == "x")
        #expect(SelectionFence.strip("<<<PROMPTDC_SELECTION>>>y<<<END_PROMPTDC_SELECTION>>>") == "y")
    }
}
