import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let store = ClipboardStore()
    private lazy var watcher = ClipboardWatcher(store: store)
    private lazy var popupController = PopupWindowController(store: store)
    private let hotkeyManager = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupHotkey()
        watcher.start()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard History")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Clipboard History", action: #selector(togglePopup), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func setupHotkey() {
        hotkeyManager.onHotKey = { [weak self] in
            self?.togglePopup()
        }
        hotkeyManager.register()
    }

    @objc private func togglePopup() {
        if popupController.isVisible {
            popupController.close()
        } else {
            popupController.show()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
