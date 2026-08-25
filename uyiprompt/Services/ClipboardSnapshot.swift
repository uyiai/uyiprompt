import AppKit

/// Full pasteboard snapshot so a synthetic ⌘C/⌘V does not destroy images/files.
struct ClipboardSnapshot {
    var changeCount: Int
    var items: [[NSPasteboard.PasteboardType: Data]]

    static func capture() -> ClipboardSnapshot {
        let board = NSPasteboard.general
        let packed: [[NSPasteboard.PasteboardType: Data]] = (board.pasteboardItems ?? []).map { item in
            var map: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    map[type] = data
                }
            }
            return map
        }
        return ClipboardSnapshot(changeCount: board.changeCount, items: packed)
    }

    func restore() {
        let board = NSPasteboard.general
        board.clearContents()
        let restored: [NSPasteboardItem] = items.map { map in
            let item = NSPasteboardItem()
            for (type, data) in map {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restored.isEmpty {
            board.writeObjects(restored)
        }
    }
}
