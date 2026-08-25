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
