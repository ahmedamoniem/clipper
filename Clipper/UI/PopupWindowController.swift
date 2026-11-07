import AppKit
import SwiftUI

@available(macOS 14.0, *)
@MainActor
final class PopupWindowController: NSWindowController, NSWindowDelegate {
    private let store: ClipboardStore
    private var isClosing = false
    private let viewModel = PopupViewModel()
    private var previousApp: NSRunningApplication?

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    init(store: ClipboardStore) {
        self.store = store
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        super.init(window: panel)
        window?.delegate = self

        let contentView = ClipboardPopupView(store: store, viewModel: viewModel) { [weak self] item in
            guard let self, let text = item.fullText else { return }
            Self.copyToPasteboard(text)
            let targetApp = previousApp
            if store.settings.autoPasteEnabled && AutoPaste.isTrusted {
                closePopup(restoreFocus: false)
                AutoPaste.paste(into: targetApp)
            } else {
                close()
            }
        } onClose: { [weak self] in
            self?.close()
        }

        let hostingController = NSHostingController(rootView: contentView)
        panel.contentView = hostingController.view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window = window else { return }
        AutoPaste.cancelPendingPaste()
        store.applyRetention()
        let defaultSelectionId = store.items.first(where: { !$0.isPinned })?.id ?? store.items.first?.id
        viewModel.resetForShow(defaultSelectionId: defaultSelectionId)
        previousApp = NSWorkspace.shared.frontmostApplication
        position(window: window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    override func close() {
        closePopup(restoreFocus: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        closePopup(restoreFocus: false)
    }

    private func position(window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let size = window.frame.size

        var x = mouse.x - size.width / 2
        var y = mouse.y - size.height / 2

        x = max(visibleFrame.minX, min(x, visibleFrame.maxX - size.width))
        y = max(visibleFrame.minY, min(y, visibleFrame.maxY - size.height))

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func closePopup(restoreFocus: Bool) {
        guard !isClosing, isVisible else { return }
        isClosing = true
        let target = previousApp
        previousApp = nil
        // orderOut can synchronously resign key; never restore focus from that callback.
        let shouldRestore = restoreFocus && NSApp.isActive && window?.isKeyWindow == true
        window?.orderOut(nil)
        if shouldRestore, let target, !target.isTerminated,
           target.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            target.activate(options: [])
        }
        isClosing = false
    }

    private static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

@available(macOS 14.0, *)
@Observable
@MainActor
final class PopupViewModel {
    var searchText: String = ""
    var selectedId: ClipboardItem.ID?
    var focusToken: UUID = UUID()
    var showSettings: Bool = false
    var isTrusted: Bool = AutoPaste.isTrusted

    func resetForShow(defaultSelectionId: ClipboardItem.ID?) {
        searchText = ""
        selectedId = defaultSelectionId
        focusToken = UUID()
        refreshTrustStatus()
    }

    func refreshTrustStatus() {
        isTrusted = AutoPaste.isTrusted
    }
}
