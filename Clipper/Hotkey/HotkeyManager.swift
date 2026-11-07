import Carbon
import Observation

@Observable
@MainActor
final class HotkeyManager {
    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var handlerRef: EventHandlerRef?
    private var currentKeyCode: Int?
    private var currentModifierFlags: Int?
    private(set) var registrationError: String?
    var onHotKey: (() -> Void)?
    nonisolated private static let signature: OSType = 0x434C4950 // CLIP

    @discardableResult
    func register(keyCode: Int, modifierFlags: Int) -> Bool {
        guard let key = UInt32(exactly: keyCode), key <= 127,
              let modifiers = UInt32(exactly: modifierFlags), modifiers != 0,
              modifiers & ~UInt32(cmdKey | optionKey | controlKey | shiftKey) == 0 else {
            registrationError = "Choose a valid key with Command, Control, Option, or Shift."
            return false
        }
        if hotKeyRef != nil, currentKeyCode == keyCode, currentModifierFlags == modifierFlags {
            registrationError = nil
            return true
        }
        if handlerRef == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                               EventParamType(typeEventHotKeyID), nil,
                                               MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard result == noErr, id.signature == HotkeyManager.signature, id.id == 1 else {
                    return OSStatus(eventNotHandledErr)
                }
                MainActor.assumeIsolated {
                    Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue().onHotKey?()
                }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
            guard status == noErr else {
                registrationError = "Could not install the shortcut handler (\(status))."
                return false
            }
        }
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: Self.signature, id: 1),
                                         GetApplicationEventTarget(), UInt32(kEventHotKeyExclusive), &newRef)
        guard status == noErr else {
            registrationError = "This shortcut could not be registered (\(status)). Try another combination."
            return false
        }
        // Keep the working shortcut until its replacement has registered successfully.
        unregister()
        hotKeyRef = newRef
        currentKeyCode = keyCode
        currentModifierFlags = modifierFlags
        registrationError = nil
        return true
    }

    @discardableResult
    func registerCurrentSettings(settings: AppSettings? = nil, preservingError: Bool = false) -> Bool {
        let settings = settings ?? .shared
        let error = registrationError
        let result = register(keyCode: settings.hotkeyKeyCode, modifierFlags: settings.hotkeyModifierFlags)
        if preservingError, let error { registrationError = error }
        return result
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
