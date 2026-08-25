import CoreGraphics

enum WindowMetrics {
    static let windowCorner: CGFloat = 16
    static let panelSize = CGSize(width: 380, height: 400)
    static let panelMinSize = CGSize(width: 360, height: 380)

    static let popoverDefault = CGSize(width: 380, height: 208)
    static let popoverMin = CGSize(width: 340, height: 180)
    static let popoverMax = CGSize(width: 420, height: 460)
    static let popoverCursorOffset = CGPoint(x: 12, y: -16)
    static let popoverEdgeGap: CGFloat = 8

    static let actionBarSize = CGSize(width: 168, height: 38)
    /// Gap between the selection and the chip bar.
    static let actionBarGap: CGFloat = 12
    /// Notes / Safari / WeChat put Copy · Look Up in this band above the selection.
    static let actionBarNativeChromeHeight: CGFloat = 52
    static let actionBarScreenInset: CGFloat = 8

    static let settingsSignedIn = CGSize(width: 860, height: 580)
    static let settingsSignedOut = CGSize(width: 700, height: 520)

    static let onboardingPreferred = CGSize(width: 680, height: 640)
    static let onboardingMin = CGSize(width: 520, height: 500)
}
