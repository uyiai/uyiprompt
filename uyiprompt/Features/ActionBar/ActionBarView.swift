import SwiftUI

struct ActionBarView: View {
    var onEnhance: () -> Void
    var onTranslate: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            chip(title: "改写", symbol: "pencil.line", action: onEnhance)
            chip(title: "翻译", symbol: "globe", action: onTranslate)
        }
        .padding(5)
    }

    private func chip(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.14), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture(perform: action)
        .help(title)
    }
}
