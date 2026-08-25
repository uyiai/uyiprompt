import CoreGraphics

enum WindowMetrics {
    static let windowCorner: CGFloat = 14
    static let panelSize = CGSize(width: 360, height: 420)
    static let panelMinSize = CGSize(width: 360, height: 420)

    static let popoverDefault = CGSize(width: 380, height: 208)
    static let popoverMin = CGSize(width: 340, height: 180)
    static let popoverMax = CGSize(width: 420, height: 460)
    static let popoverCursorOffset = CGPoint(x: 12, y: -16)
    static let popoverEdgeGap: CGFloat = 8

    static let settingsSignedIn = CGSize(width: 1020, height: 700)
    static let settingsSignedOut = CGSize(width: 700, height: 580)

    static let onboardingPreferred = CGSize(width: 680, height: 640)
    static let onboardingMin = CGSize(width: 520, height: 500)
}
