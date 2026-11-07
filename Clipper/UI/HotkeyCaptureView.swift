import SwiftUI
import Carbon
import AppKit

struct HotkeyCaptureView: NSViewRepresentable {
    var isActive: Bool
    var onCaptured: (Int, Int) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> HotkeyCaptureNSView {
        let view = HotkeyCaptureNSView()
        view.onCaptured = onCaptured
        view.onCancel = onCancel
        view.isActive = isActive
        return view
    }
    
    func updateNSView(_ nsView: HotkeyCaptureNSView, context: Context) {
        nsView.isActive = isActive
        nsView.onCaptured = onCaptured
        nsView.onCancel = onCancel
        if !isActive, nsView.window?.firstResponder === nsView {
            nsView.window?.makeFirstResponder(nil)
        }
        if isActive {
            DispatchQueue.main.async {
                guard nsView.isActive, let window = nsView.window, window.isKeyWindow else { return }
                window.makeFirstResponder(nsView)
            }
        }
    }
}

class HotkeyCaptureNSView: NSView {
    var isActive: Bool = false {
        didSet {
            if isActive {
                window?.makeFirstResponder(self)
            }
        }
    }
    var onCaptured: ((Int, Int) -> Void)?
    var onCancel: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { isActive }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isActive {
            window?.makeFirstResponder(self)
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        guard isActive else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == kVK_Escape {
            onCancel?()
            return
        }
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if mods.isEmpty { return }

        let carbonMods = HotkeyFormatter.convertToCarbonModifiers(mods)
        onCaptured?(Int(event.keyCode), Int(carbonMods))
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isActive, window?.firstResponder === self else { return false }
        keyDown(with: event)
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        // Do nothing
    }
}
