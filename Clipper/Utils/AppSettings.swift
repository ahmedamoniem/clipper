import Foundation
import Carbon

enum AppSettings {
    private static let autoPasteKey = "AutoPasteEnabled"

    static var autoPasteEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: autoPasteKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoPasteKey) }
    }

    // Hotkey settings keys
    private static let hotkeyKeyCodeKey = "HotkeyKeyCode"
    private static let hotkeyModifierFlagsKey = "HotkeyModifierFlags"

    /// The key code for the global hotkey (default: kVK_ANSI_V = 9)
    static var hotkeyKeyCode: Int {
        get {
            let value = UserDefaults.standard.value(forKey: hotkeyKeyCodeKey) as? Int
            return value ?? 9 // kVK_ANSI_V
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hotkeyKeyCodeKey)
        }
    }
    /// The modifier flags for the global hotkey (default: controlKey = 4096)
    static var hotkeyModifierFlags: Int {
        get {
            let value = UserDefaults.standard.value(forKey: hotkeyModifierFlagsKey) as? Int
            return value ?? Int(controlKey) // 4096
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hotkeyModifierFlagsKey)
        }
    }
}
