import AppKit
import SwiftUI

@MainActor
final class PopupWindowController: NSWindowController, NSWindowDelegate {
    private let store: ClipboardStore
    private let viewModel = PopupViewModel()
    private var previousApp: NSRunningApplication?

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    init(store: ClipboardStore) {
        self.store = store
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
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
            Self.copyToPasteboard(item.fullText)
            guard let self else { return }
            let targetApp = previousApp
            if AutoPaste.isTrusted {
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
        close()
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
        window?.orderOut(nil)
        if restoreFocus {
            restorePreviousApp()
        }
    }

    private func restorePreviousApp() {
        guard let previousApp else { return }
        self.previousApp = nil
        if previousApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        previousApp.activate()
    }

    private static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

@Observable
@MainActor
final class PopupViewModel {
    var searchText: String = ""
    var selectedId: ClipboardItem.ID?
    var focusToken: UUID = UUID()
    var showSettings: Bool = false

    func resetForShow(defaultSelectionId: ClipboardItem.ID?) {
        searchText = ""
        selectedId = defaultSelectionId
        focusToken = UUID()
        // We don't reset showSettings here to keep the user's last preference during the session
    }
}
