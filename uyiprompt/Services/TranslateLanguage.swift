import Foundation

enum SelectionJob: String, Equatable, Hashable, Sendable {
    case enhance
    case translate

    var verb: String {
        switch self {
        case .enhance: L10n.t("job.enhance")
        case .translate: L10n.t("job.translate")
        }
    }
}

enum TranslateLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto
    case chinese
    case english
    case japanese
    case korean
    case french
    case german
    case spanish
    case portuguese
    case russian
    case vietnamese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: L10n.t("lang.autoPair")
        case .chinese: L10n.t("lang.simplified")
        case .english: L10n.t("lang.english")
        case .japanese: L10n.t("lang.japanese")
        case .korean: L10n.t("lang.korean")
        case .french: L10n.t("lang.french")
        case .german: L10n.t("lang.german")
        case .spanish: L10n.t("lang.spanish")
        case .portuguese: L10n.t("lang.portuguese")
        case .russian: L10n.t("lang.russian")
        case .vietnamese: L10n.t("lang.vietnamese")
        }
    }

    var shortTitle: String {
        switch self {
        case .auto: L10n.t("lang.auto")
        case .chinese: L10n.t("lang.chinese")
        case .english: L10n.t("lang.english")
        case .japanese: L10n.t("lang.japanese")
        case .korean: L10n.t("lang.korean")
        case .french: L10n.t("lang.french")
        case .german: L10n.t("lang.german")
        case .spanish: L10n.t("lang.esShort")
        case .portuguese: L10n.t("lang.ptShort")
        case .russian: L10n.t("lang.russian")
        case .vietnamese: L10n.t("lang.vietnamese")
        }
    }

    var promptName: String {
        switch self {
        case .auto: "Simplified Chinese"
        case .chinese: "Simplified Chinese (简体中文)"
        case .english: "English"
        case .japanese: "Japanese (日本語)"
        case .korean: "Korean (한국어)"
        case .french: "French (français)"
        case .german: "German (Deutsch)"
        case .spanish: "Spanish (español)"
        case .portuguese: "Portuguese (português)"
        case .russian: "Russian (русский)"
        case .vietnamese: "Vietnamese (tiếng Việt)"
        }
    }

    enum ScriptGuess: Equatable, Sendable {
        case chinese
        case japanese
        case korean
        case latin
    }

    static func guess(_ text: String) -> ScriptGuess {
        var han = 0
        var kana = 0
        var hangul = 0
        var letters = 0
        for scalar in text.unicodeScalars {
            let value = scalar.value
            let isHan = (0x4E00...0x9FFF).contains(value)
                || (0x3400...0x4DBF).contains(value)
                || (0xF900...0xFAFF).contains(value)
            let isKana = (0x3040...0x309F).contains(value) || (0x30A0...0x30FF).contains(value)
            let isHangul = (0xAC00...0xD7AF).contains(value)
            if isHan || isKana || isHangul || CharacterSet.letters.contains(scalar) {
                letters += 1
                if isHan { han += 1 }
                if isKana { kana += 1 }
                if isHangul { hangul += 1 }
            }
        }
        guard letters > 0 else { return .latin }
        if hangul * 5 >= letters { return .korean }
        if kana >= 4 { return .japanese }
        if han * 4 >= letters { return .chinese }
        return .latin
    }

    static func resolve(_ preference: TranslateLanguage, text: String) -> TranslateLanguage {
        if preference != .auto { return preference }
        switch guess(text) {
        case .chinese: return .english
        case .japanese, .korean, .latin: return .chinese
        }
    }

    static func routeLabel(preference: TranslateLanguage, text: String) -> String {
        let resolved = resolve(preference, text: text)
        if preference != .auto {
            return "→\(resolved.shortTitle)"
        }
        switch guess(text) {
        case .chinese: return L10n.t("route.zhEn")
        case .japanese: return L10n.t("route.jaZh")
        case .korean: return L10n.t("route.koZh")
        case .latin: return L10n.t("route.toZh")
        }
    }
}
