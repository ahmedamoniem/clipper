import AppKit
import SwiftUI

final class PopupWindowController: NSWindowController, NSWindowDelegate {
    private let store: ClipboardStore
    private let viewModel = PopupViewModel()

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

        let contentView = ClipboardPopupView(store: store, viewModel: viewModel) { [weak panel] item in
            Self.copyToPasteboard(item.fullText)
            panel?.close()
        } onClose: { [weak panel] in
            panel?.close()
        }

        let hostingController = NSHostingController(rootView: contentView)
        panel.contentView = hostingController.view

        super.init(window: panel)
        window?.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window = window else { return }
        viewModel.resetForShow()
        position(window: window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    override func close() {
        window?.orderOut(nil)
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

    private static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

final class PopupViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedId: ClipboardItem.ID?
    @Published var focusToken: UUID = UUID()

    func resetForShow() {
        searchText = ""
        selectedId = nil
        focusToken = UUID()
    }
}
