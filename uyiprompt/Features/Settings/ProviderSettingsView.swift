import SwiftUI

/// Single-column provider list. The selected card expands to show key / model setup.
struct ProviderSettingsView: View {
    @EnvironmentObject private var session: AppSession
    @Binding var editing: LLMProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("providers.title"))
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(LLMProvider.allCases) { provider in
                    providerCard(provider)
                }
            }
        }
    }

    private func providerCard(_ provider: LLMProvider) -> some View {
        let selected = editing == provider
        let active = session.llm.activeProvider == provider

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ProviderIcon(provider: provider, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(provider.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        if active {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                        }
                    }
                    Text(selected ? provider.caption : session.llm.summary(for: provider))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if provider.isRecommended, !selected {
                    Text(L10n.t("providers.recommended"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                if selected {
                    if active {
                        StatusPill(text: L10n.t("providers.using"), tint: .green)
                    } else {
                        Button(L10n.t("providers.setCurrent")) {
                            setActive(provider)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture { editing = provider }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityLabel(provider.title)
            .accessibilityAction { editing = provider }

            if selected {
                SettingsHairline()
                ModelSetupCard(provider: provider, showsStatus: false, embedded: true)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            }
        }
        .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous)
                .strokeBorder(selected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.18), value: selected)
    }

    private func setActive(_ provider: LLMProvider) {
        var next = session.llm
        var settings = next.endpoint(provider)
        if settings.baseURL.isEmpty {
            settings.baseURL = provider.defaultBaseURL
        }
        if settings.model.isEmpty {
            settings.model = provider.defaultModel
        }
        next.providers[provider] = settings
        next.activeProvider = provider
        session.llm = next
        editing = provider
    }
}
