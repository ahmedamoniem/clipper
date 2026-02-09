import AppKit
import SwiftUI

@available(macOS 14.0, *)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let store = ClipboardStore()
    private lazy var watcher = ClipboardWatcher(store: store)
    private lazy var popupController = PopupWindowController(store: store)
    private let hotkeyManager = HotkeyManager()
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupHotkey()
        watcher.start()

        NotificationCenter.default.addObserver(self, selector: #selector(updateGlobalHotkey), name: Notification.Name.hotkeySettingsChanged, object: nil)
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

        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
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
        hotkeyManager.registerCurrentSettings()
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

    @objc func showAccessibilityGuide() {
        AutoPaste.requestPermission()
        if !AutoPaste.isTrusted {
            showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Enable Accessibility for Auto-Paste"
        alert.informativeText = "To use Auto-Paste on Enter, allow Clipper in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func showPreferences() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let preferencesView = HotkeyPreferencesView()
        let hostingController = NSHostingController(rootView: preferencesView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 700, height: 500))
        window.center()
        window.isReleasedWhenClosed = false
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func updateGlobalHotkey() {
        hotkeyManager.unregister()
        hotkeyManager.registerCurrentSettings()
    }
}
