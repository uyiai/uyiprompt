import os

/// Categorized diagnostic logging. Read with Console.app or:
///   log stream --predicate 'subsystem == "app.uyiprompt"'
enum Log {
    private static let subsystem = "app.uyiprompt"

    static let selection = Logger(subsystem: subsystem, category: "selection")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let hotkeys = Logger(subsystem: subsystem, category: "hotkeys")
}
