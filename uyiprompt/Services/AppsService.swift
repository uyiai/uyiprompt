import AppKit

struct InstalledApp: Identifiable, Hashable {
    var id: String { bundleID }
    var bundleID: String
    var name: String
    var path: String
}

enum AppsService {
    private static let skip: Set<String> = ["app.uyiprompt", "com.github.Electron"]

    static func list() -> [InstalledApp] {
        var seen = Set<String>()
        var out: [InstalledApp] = []
        let roots = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications",
        ]
        for root in roots {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for name in entries where name.hasSuffix(".app") {
                let path = (root as NSString).appendingPathComponent(name)
                guard let bundle = Bundle(path: path),
                      let bundleID = bundle.bundleIdentifier,
                      !skip.contains(bundleID),
                      seen.insert(bundleID).inserted
                else { continue }
                let display = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? (name as NSString).deletingPathExtension
                out.append(InstalledApp(bundleID: bundleID, name: display, path: path))
            }
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func icon(for path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}
