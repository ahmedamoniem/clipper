import Carbon

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    var onHotKey: (() -> Void)?

    func register() {
        unregister()
        let signature = fourCharCode("CLIP")
        var hotKeyID = EventHotKeyID(signature: signature, id: 1)

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(controlKey),
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
