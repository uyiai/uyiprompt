import Foundation
import Sparkle

/// Sparkle auto-update. The feed URL and update checks live in Info.plist
/// (SUFeedURL / SUEnableAutomaticChecks); update archives are validated via
/// Apple Developer ID code signing.
@MainActor
final class UpdateService {
    static let shared = UpdateService()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private init() {}

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
