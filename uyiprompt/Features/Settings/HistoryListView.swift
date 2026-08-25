import AppKit
import SwiftUI

struct HistoryListView: View {
    @ObservedObject var store: HistoryStore
    @EnvironmentObject private var windows: AppWindows

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("nav.history"))
                    .font(.headline)
                Spacer()
                if !store.items.isEmpty {
                    Button(L10n.t("history.clear"), role: .destructive) {
                        store.clear()
                    }
                    .controlSize(.small)
                }
            }
            if store.items.isEmpty {
                Text(L10n.t("history.empty"))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(store.items) { item in
                        historyCard(item)
                    }
                }
            }
        }
    }

    private func historyCard(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.job == .translate ? L10n.t("job.translate") : item.label)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(item.preview)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack(spacing: 8) {
                Button(L10n.t("history.copyResult")) {
                    copy(item.result)
                }
                .controlSize(.small)
                Button(L10n.t("history.reuse")) {
                    windows.showPanel(draft: item.original, job: item.job)
                }
                .controlSize(.small)
                Spacer()
                Button(L10n.t("history.delete"), role: .destructive) {
                    store.remove(item)
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(UIChrome.cardFill, in: RoundedRectangle(cornerRadius: UIChrome.radius, style: .continuous))
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}