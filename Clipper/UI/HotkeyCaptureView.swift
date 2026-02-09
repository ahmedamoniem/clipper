import SwiftUI
import Carbon
import AppKit

struct HotkeyCaptureView: NSViewRepresentable {
    var isActive: Bool
    var onCaptured: (Int, Int) -> Void

    func makeNSView(context: Context) -> HotkeyCaptureNSView {
        let view = HotkeyCaptureNSView()
        view.onCaptured = onCaptured
        view.isActive = isActive
        return view
    }
    
    func updateNSView(_ nsView: HotkeyCaptureNSView, context: Context) {
        nsView.isActive = isActive
        nsView.onCaptured = onCaptured
        if isActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
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
    
    override var acceptsFirstResponder: Bool { true }
    
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
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if mods.isEmpty { return }

        let carbonMods = HotkeyFormatter.convertToCarbonModifiers(mods)
        onCaptured?(Int(event.keyCode), Int(carbonMods))
    }
    
    override func flagsChanged(with event: NSEvent) {
        // Do nothing
    }
}
