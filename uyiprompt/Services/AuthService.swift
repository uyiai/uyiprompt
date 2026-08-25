import Foundation

/// Session owner. Production exchanges PKCE on `uyiprompt://auth` in AppKit
/// (AppDelegate), matching Electron's main-process auth-manager.
enum AuthService {
    static let urlScheme = "uyiprompt"
}
