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
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedStatus == .success, let focused else { return nil }
        let element = unsafeBitCast(focused, to: AXUIElement.self)
        var value: CFTypeRef?
        let textStatus = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard textStatus == .success else { return nil }
        return value as? String
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
