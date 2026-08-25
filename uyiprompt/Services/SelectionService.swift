import AppKit
import ApplicationServices
import Foundation

struct SelectionCapture {
    var text: String
    var bundleID: String?
    var usedClipboardFallback: Bool
    var accessibilityDenied: Bool
}

struct SelectionPasteResult {
    var ok: Bool
    var accessibilityDenied: Bool
    var error: String?
}

/// Cross-app selection capture and paste-back.
/// Same shape as Electron `selection.js`, using AX + CGEvent instead of osascript.
@MainActor
enum SelectionService {
    static let ownBundleIDs: Set<String> = ["app.uyiprompt"]
    static let accessDeniedMessage =
        "辅助功能开关对不上当前这份程序。请到系统设置 → 隐私与安全性 → 辅助功能：删掉旧的 uyiprompt，再把「应用程序」里的 uyiprompt 拖进去打开。"

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func promptForAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    static func requestAccess() {
        promptForAccessibility()
        openAccessibilitySettings()
    }

    static func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    static func isOwnApp(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return ownBundleIDs.contains(bundleID)
    }

    static func activate(bundleID: String) -> Bool {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard let app = running.first else { return false }
        return app.activate()
    }

    static func waitUntilFrontmost(_ bundleID: String, timeoutMs: Int = 1500) async -> Bool {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        while Date() < deadline {
            if frontmostBundleID() == bundleID { return true }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        return frontmostBundleID() == bundleID
    }

    static func waitForModifiersReleased(timeoutMs: Int = 400) async {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        while Date() < deadline {
            if !KeystrokeSynthesizer.blockingModifiersDown { return }
            try? await Task.sleep(nanoseconds: 45_000_000)
        }
    }

    static func readSelection(preferredBundleID: String? = nil) async -> SelectionCapture {
        if !isTrusted {
            return SelectionCapture(text: "", bundleID: preferredBundleID ?? frontmostBundleID(), usedClipboardFallback: false, accessibilityDenied: true)
        }

        await waitForModifiersReleased()

        let bundleID = preferredBundleID ?? frontmostBundleID()
        if isOwnApp(bundleID) {
            return SelectionCapture(text: "", bundleID: bundleID, usedClipboardFallback: false, accessibilityDenied: false)
        }

        if let ax = axSelectedText(), !ax.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return SelectionCapture(text: ax, bundleID: bundleID, usedClipboardFallback: false, accessibilityDenied: false)
        }

        let copied = await copyViaClipboard()
        return SelectionCapture(
            text: copied ?? "",
            bundleID: bundleID,
            usedClipboardFallback: true,
            accessibilityDenied: false
        )
    }

    static func paste(_ text: String, into bundleID: String?) async -> SelectionPasteResult {
        if !isTrusted {
            return SelectionPasteResult(ok: false, accessibilityDenied: true, error: accessDeniedMessage)
        }
        if let bundleID {
            _ = activate(bundleID: bundleID)
            let front = await waitUntilFrontmost(bundleID)
            if !front {
                return SelectionPasteResult(ok: false, accessibilityDenied: false, error: "请切回原来的软件再试一次")
            }
        }

        await waitForModifiersReleased()
        let snapshot = ClipboardSnapshot.capture()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        KeystrokeSynthesizer.commandV()
        try? await Task.sleep(nanoseconds: 400_000_000)
        snapshot.restore()
        return SelectionPasteResult(ok: true, accessibilityDenied: false, error: nil)
    }

    // MARK: - AX

    static func axSelectedText() -> String? {
        axSelectionSnapshot().text
    }

    struct AXSelectionSnapshot {
        var text: String
        var cocoaBounds: CGRect?
        var role: String?
        var subrole: String?
        var bundleID: String?

        var isSecure: Bool {
            subrole == (kAXSecureTextFieldSubrole as String) || role == "AXSecureTextField"
        }

        var isIgnorableRole: Bool {
            let skip: Set<String> = [
                "AXButton", "AXMenu", "AXMenuItem", "AXMenuBarItem",
                "AXSlider", "AXScrollBar", "AXCheckBox", "AXRadioButton",
                "AXPopUpButton", "AXTabGroup", "AXToolbar",
            ]
            if let role, skip.contains(role) { return true }
            return false
        }
    }

    static func axSelectionSnapshot() -> AXSelectionSnapshot {
        let bundle = frontmostBundleID()
        let empty = AXSelectionSnapshot(text: "", cocoaBounds: nil, role: nil, subrole: nil, bundleID: bundle)
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedStatus == .success, let focused else { return empty }
        let element = unsafeBitCast(focused, to: AXUIElement.self)

        var textRef: CFTypeRef?
        var text = ""
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &textRef) == .success {
            text = textRef as? String ?? ""
        }

        var roleRef: CFTypeRef?
        var role: String?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success {
            role = roleRef as? String
        }
        var subRef: CFTypeRef?
        var subrole: String?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subRef) == .success {
            subrole = subRef as? String
        }

        var cocoaBounds: CGRect?
        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let rangeRef {
            var boundsRef: CFTypeRef?
            let status = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                rangeRef,
                &boundsRef
            )
            if status == .success, let boundsRef, CFGetTypeID(boundsRef) == AXValueGetTypeID() {
                let axValue = unsafeBitCast(boundsRef, to: AXValue.self)
                var cg = CGRect.zero
                if AXValueGetValue(axValue, .cgRect, &cg), cg.width > 1, cg.height > 1 {
                    cocoaBounds = cocoaRect(fromAX: cg)
                }
            }
        }

        return AXSelectionSnapshot(text: text, cocoaBounds: cocoaBounds, role: role, subrole: subrole, bundleID: bundle)
    }

    /// Chromium and some Electron apps only expose AX after this is set.
    static func enableEnhancedAccessibility() {
        guard let bundleID = frontmostBundleID(),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(element, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }

    /// Brief ⌘C with clipboard restore. Only for selection-bar fallback.
    static func peekClipboardSelection() async -> String? {
        await copyViaClipboard()
    }

    /// Accessibility bounds use a top-left origin on the primary display.
    private static func cocoaRect(fromAX rect: CGRect) -> CGRect {
        let primaryMaxY = NSScreen.screens.first(where: { $0.frame.minX == 0 && $0.frame.minY == 0 })?.frame.maxY
            ?? NSScreen.main?.frame.maxY
            ?? 0
        return CGRect(
            x: rect.origin.x,
            y: primaryMaxY - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Clipboard fallback

    private static func copyViaClipboard() async -> String? {
        let snapshot = ClipboardSnapshot.capture()
        let startCount = NSPasteboard.general.changeCount
        KeystrokeSynthesizer.commandC()

        let deadline = Date().addingTimeInterval(0.8)
        var text: String?
        while Date() < deadline {
            if NSPasteboard.general.changeCount != startCount {
                text = NSPasteboard.general.string(forType: .string)
                break
            }
            try? await Task.sleep(nanoseconds: 12_000_000)
        }

        snapshot.restore()
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }
}
