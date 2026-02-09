import Carbon

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    var onHotKey: (() -> Void)?

    private var currentKeyCode: Int = 9 // default kVK_ANSI_V
    private var currentModifierFlags: Int = Int(controlKey) // default 4096

    func register(keyCode: Int, modifierFlags: Int) {
        unregister()

        currentKeyCode = keyCode
        currentModifierFlags = modifierFlags

        let signature = fourCharCode("CLIP")
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifierFlags),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            Logging.debug("Failed to register hotkey: \(status)")
            return
        }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKey?()
                return noErr
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &handlerRef
        )
        guard installStatus == noErr else {
            Logging.debug("Failed to install hotkey handler: \(installStatus)")
            if let hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
            hotKeyRef = nil
            handlerRef = nil
            return
        }
    }

    func registerCurrentSettings() {
        register(keyCode: AppSettings.hotkeyKeyCode, modifierFlags: AppSettings.hotkeyModifierFlags)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil

        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        handlerRef = nil
    }

    deinit {
        unregister()
    }
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for scalar in string.utf8.prefix(4) {
        result = (result << 8) + FourCharCode(scalar)
    }
    return result
}
