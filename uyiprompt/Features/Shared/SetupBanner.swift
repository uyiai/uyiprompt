import SwiftUI

struct SetupBanner: View {
    let icon: String
    let text: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.orange)
            Text(text)
                .font(.callout)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(actionTitle, action: action)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ShortcutChip: View {
    let text: String
    var help: String = ""

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium).monospaced())
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.05), in: Capsule())
            .help(help)
    }
}

struct HowToStrip: View {
    var shortcut: String = L10n.t("howto.action")
    var action: String = L10n.t("howto.replace")

    var body: some View {
        HStack(spacing: 10) {
            HowToStep(symbol: "character.cursor.ibeam", title: L10n.t("howto.select"))
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            HowToStep(symbol: "capsule", title: shortcut)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            HowToStep(symbol: "arrow.uturn.forward", title: action)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
    }
}

private struct HowToStep: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            Text(title)
                .font(.callout.weight(.medium))
        }
    }
}

struct CapsuleChooser<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, title in
                Button {
                    selection = value
                } label: {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            selection == value ? Color.accentColor : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(selection == value ? Color.white : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}

struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.weight(.semibold).monospaced())
            .frame(minWidth: 36)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .shadow(color: Color.black.opacity(0.12), radius: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }
}

struct MenuBarHintView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AppMark(size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("hint.menubar"))
                    .font(.headline)
                Text(L10n.t("hint.action"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
