import SwiftUI

/// Cherry Studio / LobeChat style: provider list on the left, config on the right.
struct ProviderSettingsView: View {
    @EnvironmentObject private var session: AppSession
    @Binding var editing: LLMProvider

    var body: some View {
        HStack(spacing: 0) {
            providerList
                .frame(width: 248)
            Divider().opacity(0.3)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var providerList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("服务商")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(LLMProvider.allCases) { provider in
                providerRow(provider)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .background(Color.primary.opacity(0.025))
    }

    private func providerRow(_ provider: LLMProvider) -> some View {
        let selected = editing == provider
        let active = session.llm.activeProvider == provider
        let configured = session.llm.isConfigured(provider)

        return HStack(spacing: 4) {
            Button {
                editing = provider
            } label: {
                HStack(spacing: 10) {
                    ProviderIcon(provider: provider, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(provider.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            if provider.isRecommended {
                                Text("推荐")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                        }
                        Text(session.llm.summary(for: provider))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(provider.title)

            Button {
                setActive(provider)
            } label: {
                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(active ? Color.green : Color.secondary.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(active ? "当前使用" : "设为当前服务")
            .accessibilityLabel(active ? "当前使用 \(provider.title)" : "设 \(provider.title) 为当前")
            .opacity(active || configured ? 1 : 0.7)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .background(
            selected ? Color.primary.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selected ? Color.primary.opacity(0.06) : Color.clear, lineWidth: 1)
        )
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    ProviderIcon(provider: editing, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(editing.title)
                            .font(.title2.weight(.semibold))
                        Text(editing.caption)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if session.llm.activeProvider == editing {
                        Label("当前使用", systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Color.green)
                    } else {
                        Button {
                            setActive(editing)
                        } label: {
                            Label("设为当前", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                ModelSetupCard(provider: editing)
            }
            .padding(24)
        }
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
