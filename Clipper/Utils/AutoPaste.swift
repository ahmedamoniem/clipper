import AppKit
import Carbon
import ApplicationServices

enum AutoPaste {
    enum PasteDispatchDecision: Equatable {
        case send
        case retry(nextRetriesRemaining: Int)
    }

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

    static func pasteDispatchDecision(
        frontmostPID: pid_t?,
        targetPID: pid_t,
        retriesRemaining: Int
    ) -> PasteDispatchDecision {
        if frontmostPID == targetPID || retriesRemaining <= 0 {
            return .send
        }
        return .retry(nextRetriesRemaining: retriesRemaining - 1)
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
        let decision = pasteDispatchDecision(
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            targetPID: targetApp.processIdentifier,
            retriesRemaining: retriesRemaining
        )
        switch decision {
        case .send:
            sendCmdV()
        case .retry(let nextRetriesRemaining):
            targetApp.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + pasteRetryInterval) {
                sendCmdVWhenFrontmost(targetApp: targetApp, retriesRemaining: nextRetriesRemaining)
            }
        }
    }
}
