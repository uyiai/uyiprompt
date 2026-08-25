import AppKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var windows: AppWindows
    @EnvironmentObject private var session: AppSession
    @State private var step = 0
    @State private var accessibilityOn = SelectionService.isTrusted

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.accentColor : Color.primary.opacity(0.12))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

            Group {
                switch step {
                case 0: welcome
                case 1: access
                default: modelStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                if step == 0 {
                    Button(L10n.t("onboard.later")) { windows.completeOnboarding() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else {
                    Button(L10n.t("onboard.back")) { step = max(0, step - 1) }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(primaryTitle) {
                    if step == 2 {
                        windows.completeOnboarding()
                    } else {
                        step += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .controlSize(.large)
            }
            .padding(24)
        }
        .frame(
            minWidth: WindowMetrics.onboardingMin.width,
            minHeight: WindowMetrics.onboardingMin.height
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UIChrome.canvasFill)
        .id(session.uiLanguage)
        .onAppear { accessibilityOn = SelectionService.isTrusted }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityOn = SelectionService.isTrusted
        }
    }

    private var primaryTitle: String {
        switch step {
        case 2: session.llm.isReady ? L10n.t("onboard.start") : L10n.t("onboard.menubar")
        default: L10n.t("onboard.continue")
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 8) {
                ColorTile(symbol: "pencil.and.outline", color: Color(red: 0.20, green: 0.48, blue: 1.00), size: 36)
                Text(L10n.t("onboard.welcome.title"))
                    .font(.title.weight(.semibold))
                Text(L10n.t("onboard.welcome.caption"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Picker(L10n.t("language.section"), selection: $session.uiLanguage) {
                ForEach(AppLanguage.allCases) { item in
                    Text(item.pickerTitle).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            VStack(alignment: .leading, spacing: 16) {
                getStartedRow(symbol: "character.cursor.ibeam", color: Color(red: 0.20, green: 0.48, blue: 1.00), title: L10n.t("onboard.step1.title"), caption: L10n.t("onboard.step1.caption"))
                getStartedRow(symbol: "pencil.line", color: Color(red: 0.18, green: 0.40, blue: 0.95), title: L10n.t("onboard.step2.title"), caption: L10n.t("onboard.step2.caption"))
                getStartedRow(symbol: "arrow.uturn.forward", color: Color(red: 0.18, green: 0.72, blue: 0.36), title: L10n.t("onboard.step3.title"), caption: L10n.t("onboard.step3.caption"))
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private func getStartedRow(symbol: String, color: Color, title: String, caption: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ColorTile(symbol: symbol, color: color, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var access: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)
            IconBadge(symbol: "accessibility", size: 64)
            Text(L10n.t("onboard.access.title"))
                .font(.largeTitle.weight(.semibold))
            Text(L10n.t("onboard.access.caption"))
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Text(accessibilityOn ? L10n.t("onboard.access.ok") : L10n.t("onboard.access.need"))
                .foregroundStyle(accessibilityOn ? Color.green : Color.secondary)
            if !accessibilityOn {
                Button {
                    SelectionService.requestAccess()
                } label: {
                    Label(L10n.t("onboard.access.open"), systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 32)
    }

    private var modelStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("onboard.model.title"))
                    .font(.title.weight(.semibold))
                Text(session.llm.isReady
                     ? L10n.t("onboard.model.ready")
                     : L10n.t("onboard.model.need"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                ModelSetupCard(provider: session.llm.activeProvider, compact: true, showProviderPicker: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppWindows())
        .environmentObject(AppSession())
        .frame(width: 640, height: 620)
}
