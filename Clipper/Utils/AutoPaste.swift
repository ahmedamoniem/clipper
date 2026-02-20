import AppKit
import Carbon
import ApplicationServices

enum AutoPaste {
    private static let pasteRetryInterval: TimeInterval = 0.05
    private static let maxPasteActivationRetries = 8

    /// Silently checks if the app is trusted.
    static var isTrusted: Bool {
        isTrusted(prompt: false)
    }

    /// Requests permission by showing the system prompt.
    static func requestPermission() {
        _ = isTrusted(prompt: true)
    }

    static func paste(into app: NSRunningApplication?) {
        guard let app else { return }
        guard isTrusted else {
            requestPermission()
            return
        }

        app.activate(options: [])
        sendCmdVWhenFrontmost(targetApp: app, retriesRemaining: maxPasteActivationRetries)
    }

    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func sendCmdV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private static func sendCmdVWhenFrontmost(targetApp: NSRunningApplication, retriesRemaining: Int) {
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if frontmostPID == targetApp.processIdentifier || retriesRemaining <= 0 {
            sendCmdV()
            return
        }

        targetApp.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteRetryInterval) {
            sendCmdVWhenFrontmost(targetApp: targetApp, retriesRemaining: retriesRemaining - 1)
        }
    }
}
