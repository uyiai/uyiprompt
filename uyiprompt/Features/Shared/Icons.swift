import AppKit
import SwiftUI

enum UIChrome {
    static let radius: CGFloat = 16
    static let radiusSmall: CGFloat = 10
    static let navRadius: CGFloat = 10
    static let sidebarWidth: CGFloat = 176
    static var cardFill: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.22, alpha: 1)
                : NSColor.white
        })
    }
    static var canvasFill: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.14, alpha: 1)
                : NSColor(white: 0.93, alpha: 1)
        })
    }
    static let cardStroke = Color.primary.opacity(0.04)
    static let sidebarFill = Color.clear
    static var hairline: Color { Color.primary.opacity(0.08) }
}

struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
        }
    }
}

struct SettingsHairline: View {
    var body: some View {
        Rectangle()
            .fill(UIChrome.hairline)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

struct ColorTile: View {
    let symbol: String
    var color: Color = .accentColor
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
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
    var color: Color = .accentColor
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ColorTile(symbol: symbol, color: color, size: 22)
                Text(title)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                selected ? UIChrome.cardFill : Color.clear,
                in: RoundedRectangle(cornerRadius: UIChrome.navRadius, style: .continuous)
            )
            .shadow(color: selected ? Color.black.opacity(0.08) : .clear, radius: 8, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct AppearanceChooser: View {
    @Binding var selection: AppSession.AppearancePreference

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppSession.AppearancePreference.allCases) { item in
                Button {
                    selection = item
                } label: {
                    VStack(spacing: 6) {
                        AppearanceThumbnail(preference: item)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        selection == item ? Color.accentColor : Color.primary.opacity(0.12),
                                        lineWidth: selection == item ? 2 : 1
                                    )
                            )
                        Text(item.title)
                            .font(.caption)
                            .foregroundStyle(selection == item ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AppearanceThumbnail: View {
    let preference: AppSession.AppearancePreference

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(sky)
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 5, height: 5)
                    Circle().fill(Color.yellow.opacity(0.85)).frame(width: 5, height: 5)
                    Circle().fill(Color.green.opacity(0.85)).frame(width: 5, height: 5)
                    Spacer(minLength: 0)
                }
                .padding(5)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(pane)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            }
        }
        .frame(width: 64, height: 44)
    }

    private var sky: LinearGradient {
        switch preference {
        case .system:
            LinearGradient(colors: [Color(red: 0.45, green: 0.62, blue: 0.92), Color(red: 0.78, green: 0.86, blue: 0.96)], startPoint: .top, endPoint: .bottom)
        case .light:
            LinearGradient(colors: [Color(red: 0.72, green: 0.84, blue: 0.96), Color(red: 0.93, green: 0.95, blue: 0.98)], startPoint: .top, endPoint: .bottom)
        case .dark:
            LinearGradient(colors: [Color(red: 0.10, green: 0.16, blue: 0.32), Color(red: 0.16, green: 0.18, blue: 0.28)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var pane: Color {
        switch preference {
        case .dark: Color.white.opacity(0.12)
        default: Color.white.opacity(0.86)
        }
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
