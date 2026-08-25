import SwiftUI

enum UIChrome {
    static let radius: CGFloat = 12
    static let radiusSmall: CGFloat = 8
    static let cardFill = Color.primary.opacity(0.045)
    static let cardStroke = Color.primary.opacity(0.06)
    static let sidebarFill = Color.primary.opacity(0.035)
}

struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous)
                    .strokeBorder(UIChrome.cardStroke, lineWidth: 1)
            )
    }
}

struct IconButton: View {
    let symbol: String
    var help: String = ""
    var active: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Color.accentColor : Color.secondary)
                .frame(width: 26, height: 26)
                .background(
                    Color.primary.opacity(active ? 0.08 : 0.05),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct StatusPill: View {
    let text: String
    var tint: Color = .green
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

/// App glyph used in settings, onboarding, and the panel header.
struct AppMark: View {
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "pencil.and.outline")
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color.accentColor.opacity(0.28), radius: size * 0.08, y: 1)
    }
}

struct IconBadge: View {
    let symbol: String
    var size: CGFloat = 56
    var tint: Color = .accentColor

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.38, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: Circle())
    }
}

struct ProviderIcon: View {
    let provider: LLMProvider
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(provider.gradient)
            Image(systemName: provider.symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .shadow(color: provider.accent.opacity(0.3), radius: max(1, size * 0.06), y: 1)
        .accessibilityLabel(provider.title)
    }
}

struct SettingsNavRow: View {
    let title: String
    let symbol: String
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .symbolVariant(selected ? .fill : .none)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .frame(width: 22)
                Text(title)
                    .font(.body.weight(selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                selected ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension LLMProvider {
    var symbol: String {
        switch self {
        case .deepseek: "fish.fill"
        case .openai: "sparkles"
        case .moonshot: "moon.fill"
        case .custom: "puzzlepiece.extension.fill"
        }
    }

    var accent: Color {
        switch self {
        case .deepseek: Color(red: 0.29, green: 0.43, blue: 0.98)
        case .openai: Color(red: 0.08, green: 0.63, blue: 0.50)
        case .moonshot: Color(red: 0.18, green: 0.17, blue: 0.22)
        case .custom: Color(red: 0.40, green: 0.37, blue: 0.90)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.95), accent.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var isRecommended: Bool { self == .deepseek }
}

extension WritingProfile {
    var symbol: String {
        switch id {
        case "grammar": "checkmark.seal"
        case "email": "envelope"
        case "social": "bubble.left.and.bubble.right"
        case "image-prompt": "paintbrush.pointed"
        case "summarize": "doc.text"
        case "reply": "arrowshape.turn.up.left"
        case "professional": "briefcase"
        case "concise": "text.alignleft"
        case "explain": "text.bubble"
        case "code": "chevron.left.forwardslash.chevron.right"
        default: "text.book.closed"
        }
    }
}
