import Foundation
import Carbon
import Observation

@available(macOS 14.0, *)
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()
    private let historyLimitKey = "HistoryLimit"
    private let autoCleanEnabledKey = "AutoCleanEnabled"
    private let autoCleanDaysKey = "AutoCleanDays"
    private let defaults: UserDefaults

    var historyLimit: Int {
        get {
            access(keyPath: \.historyLimit)
            let limit = defaults.integer(forKey: historyLimitKey)
            return max(1, min(limit == 0 ? 500 : limit, 1000))
        }
        set {
            withMutation(keyPath: \.historyLimit) {
                defaults.set(max(1, min(newValue, 1000)), forKey: historyLimitKey)
            }
        }
    }
    
    var autoCleanEnabled: Bool {
        get {
            access(keyPath: \.autoCleanEnabled)
            return defaults.bool(forKey: autoCleanEnabledKey)
        }
        set {
            withMutation(keyPath: \.autoCleanEnabled) {
                defaults.set(newValue, forKey: autoCleanEnabledKey)
            }
        }
    }
    
    var autoCleanDays: Int {
        get {
            access(keyPath: \.autoCleanDays)
            let days = defaults.integer(forKey: autoCleanDaysKey)
            let effectiveDays = (days == 0 ? 10 : days)
            let clampedDays = max(1, min(effectiveDays, 365))
            return clampedDays
        }
        set {
            withMutation(keyPath: \.autoCleanDays) {
                let clampedDays = max(1, min(newValue, 365))
                defaults.set(clampedDays, forKey: autoCleanDaysKey)
            }
        }
    }

    // Hotkey settings keys
    private let hotkeyKeyCodeKey = "HotkeyKeyCode"
    private let hotkeyModifierFlagsKey = "HotkeyModifierFlags"

    /// The key code for the global hotkey (default: kVK_ANSI_V = 9)
    var hotkeyKeyCode: Int {
        get {
            let value = defaults.value(forKey: hotkeyKeyCodeKey) as? Int
            return value ?? 9 // kVK_ANSI_V
        }
        set {
            defaults.set(newValue, forKey: hotkeyKeyCodeKey)
        }
    }
    /// The modifier flags for the global hotkey (default: controlKey = 4096)
    var hotkeyModifierFlags: Int {
        get {
            let value = defaults.value(forKey: hotkeyModifierFlagsKey) as? Int
            return value ?? Int(controlKey) // 4096
        }
        set {
            defaults.set(newValue, forKey: hotkeyModifierFlagsKey)
        }
    }

    var autoPasteEnabled: Bool {
        get {
            access(keyPath: \.autoPasteEnabled)
            return defaults.bool(forKey: "AutoPasteEnabled")
        }
        set {
            withMutation(keyPath: \.autoPasteEnabled) {
                defaults.set(newValue, forKey: "AutoPasteEnabled")
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}
