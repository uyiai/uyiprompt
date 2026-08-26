import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case chinese
    case english

    var id: String { rawValue }

    enum Resolved: String, Sendable {
        case chinese
        case english
    }

    /// Labels that stay in their own language so the switcher is always findable.
    var pickerTitle: String {
        switch self {
        case .system: L10n.t("language.system")
        case .chinese: "中文"
        case .english: "English"
        }
    }

    var resolved: Resolved {
        switch self {
        case .chinese: return .chinese
        case .english: return .english
        case .system:
            let code = Locale.preferredLanguages.first ?? ""
            return code.hasPrefix("zh") ? .chinese : .english
        }
    }

    var locale: Locale {
        switch resolved {
        case .chinese: Locale(identifier: "zh-Hans")
        case .english: Locale(identifier: "en")
        }
    }
}

enum L10n {
    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var value: AppLanguage.Resolved = .chinese

        var current: AppLanguage.Resolved {
            get {
                lock.lock()
                defer { lock.unlock() }
                return value
            }
            set {
                lock.lock()
                value = newValue
                lock.unlock()
            }
        }
    }

    private static let box = Box()

    static var current: AppLanguage.Resolved {
        get { box.current }
        set { box.current = newValue }
    }

    static func sync(_ language: AppLanguage) {
        current = language.resolved
    }

    /// Strings live in Resources/Localizable.xcstrings. Lookup goes through
    /// per-language bundles so the in-app language override works regardless
    /// of the system locale.
    static func t(_ key: String) -> String {
        t(key, in: current)
    }

    /// Explicit-language lookup; avoids depending on the process-wide `current`.
    static func t(_ key: String, in language: AppLanguage.Resolved) -> String {
        let missing = "\u{7F}"
        let primary = language == .chinese ? zhBundle : enBundle
        if let value = primary?.localizedString(forKey: key, value: missing, table: nil), value != missing {
            return value
        }
        if let value = zhBundle?.localizedString(forKey: key, value: missing, table: nil), value != missing {
            return value
        }
        return key
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    private static let zhBundle = languageBundle("zh-Hans")
    private static let enBundle = languageBundle("en")

    private static func languageBundle(_ code: String) -> Bundle? {
        let host = Bundle(for: BundleToken.self)
        guard let path = host.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }

    private final class BundleToken {}
}

extension WritingProfile {
    var localizedName: String {
        guard builtin else { return name }
        let fresh = WritingProfile.builtins.first(where: { $0.id == id })?.name
        let stale = WritingProfile.previousNames[id] ?? []
        if name == fresh || stale.contains(name) {
            return L10n.t("profile.\(id)")
        }
        return name
    }
}
