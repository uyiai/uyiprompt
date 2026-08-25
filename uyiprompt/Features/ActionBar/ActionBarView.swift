import SwiftUI

struct ActionBarView: View {
    @EnvironmentObject private var session: AppSession
    var onEnhance: () -> Void
    var onTranslate: () -> Void

    var body: some View {
        let _ = session.uiLanguage
        HStack(spacing: 2) {
            chip(title: L10n.t("job.enhance"), symbol: "pencil.line", action: onEnhance)
            chip(title: L10n.t("job.translate"), symbol: "globe", action: onTranslate)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.12), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
        )
        .clipShape(Capsule(style: .continuous))
    }

    private func chip(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.white.opacity(0.92))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .contentShape(Capsule())
        .onTapGesture(perform: action)
        .help(title)
    }
}
