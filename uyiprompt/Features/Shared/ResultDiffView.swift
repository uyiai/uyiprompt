import SwiftUI

enum ResultViewMode: String, CaseIterable, Identifiable {
    case changes
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .changes: L10n.t("result.changes")
        case .edit: L10n.t("result.edit")
        }
    }

    static func `default`(forProfileID id: String) -> ResultViewMode {
        id == "grammar" ? .changes : .edit
    }
}

struct DiffRun: Identifiable {
    let id = UUID()
    let kind: Kind
    let text: String

    enum Kind { case same, add, del }
}

enum ResultDiff {
    private static let cap = 800

    static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init)
    }

    static func runs(original: String, current: String) -> [DiffRun] {
        let a = Array(original)
        let b = Array(current)
        if a.count > cap || b.count > cap {
            return [DiffRun(kind: .add, text: current)]
        }
        let table = lcs(a, b)
        var runs: [DiffRun] = []
        var i = 0
        var j = 0
        func append(_ kind: DiffRun.Kind, _ ch: Character) {
            if let last = runs.last, last.kind == kind {
                runs[runs.count - 1] = DiffRun(kind: kind, text: last.text + String(ch))
            } else {
                runs.append(DiffRun(kind: kind, text: String(ch)))
            }
        }
        while i < a.count && j < b.count {
            if a[i] == b[j] {
                append(.same, b[j])
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                append(.del, a[i])
                i += 1
            } else {
                append(.add, b[j])
                j += 1
            }
        }
        while i < a.count { append(.del, a[i]); i += 1 }
        while j < b.count { append(.add, b[j]); j += 1 }
        return runs
    }

    private static func lcs(_ a: [Character], _ b: [Character]) -> [[UInt16]] {
        var table = Array(repeating: Array(repeating: UInt16(0), count: b.count + 1), count: a.count + 1)
        if a.isEmpty || b.isEmpty { return table }
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        return table
    }
}

struct ResultDiffView: View {
    let original: String
    let current: String

    var body: some View {
        Text(attributed)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributed: AttributedString {
        var output = AttributedString()
        for run in ResultDiff.runs(original: original, current: current) {
            var piece = AttributedString(run.text)
            switch run.kind {
            case .same:
                break
            case .add:
                piece.backgroundColor = Color.green.opacity(0.18)
                piece.foregroundColor = Color.green
            case .del:
                piece.strikethroughStyle = .single
                piece.backgroundColor = Color.red.opacity(0.16)
                piece.foregroundColor = Color.red.opacity(0.85)
            }
            output.append(piece)
        }
        return output
    }
}

struct ResultViewToggle: View {
    @Binding var mode: ResultViewMode
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ResultViewMode.allCases) { item in
                Button(item.title) { mode = item }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(mode == item ? Color.primary.opacity(0.12) : Color.clear, in: Capsule())
                    .disabled(disabled)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}
