import AppKit
import Carbon
import ApplicationServices

@MainActor
enum AutoPaste {
    enum PasteDispatchDecision: Equatable {
        case send
        case cancel
        case retry(nextRetriesRemaining: Int)
    }

    private static var requestID = UUID()

    static func cancelPendingPaste() {
        requestID = UUID()
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
        cancelPendingPaste()
        guard let app, !app.isTerminated,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              AppSettings.shared.autoPasteEnabled, isTrusted else { return }
        let id = requestID
        let changeCount = NSPasteboard.general.changeCount
        guard app.activate(options: []) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteRetryInterval) {
            sendCmdVWhenFrontmost(targetApp: app, retriesRemaining: maxPasteActivationRetries,
                                 request: id, changeCount: changeCount)
        }
    }

    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    nonisolated static func pasteDispatchDecision(
        frontmostPID: pid_t?,
        targetPID: pid_t,
        retriesRemaining: Int
    ) -> PasteDispatchDecision {
        if frontmostPID == targetPID {
            return .send
        }
        guard retriesRemaining > 0 else { return .cancel }
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

    private static func sendCmdVWhenFrontmost(targetApp: NSRunningApplication, retriesRemaining: Int,
                                            request: UUID, changeCount: Int) {
        guard request == requestID, !targetApp.isTerminated,
              NSPasteboard.general.changeCount == changeCount,
              AppSettings.shared.autoPasteEnabled, isTrusted else { return }
        let decision = pasteDispatchDecision(
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            targetPID: targetApp.processIdentifier,
            retriesRemaining: retriesRemaining
        )
        switch decision {
        case .send:
            sendCmdV()
        case .cancel:
            return
        case .retry(let nextRetriesRemaining):
            DispatchQueue.main.asyncAfter(deadline: .now() + pasteRetryInterval) {
                sendCmdVWhenFrontmost(targetApp: targetApp, retriesRemaining: nextRetriesRemaining,
                                     request: request, changeCount: changeCount)
            }
        }
    }
}
