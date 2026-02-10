import Foundation
import Carbon
import SwiftUI
import Observation

@available(macOS 14.0, *)
@Observable
final class AppSettings {
    static let shared = AppSettings()
    private let historyLimitKey = "HistoryLimit"
    private let autoCleanEnabledKey = "AutoCleanEnabled"
    private let autoCleanDaysKey = "AutoCleanDays"

    var historyLimit: Int {
        get {
            access(keyPath: \.historyLimit)
            let limit = UserDefaults.standard.integer(forKey: historyLimitKey)
            return limit == 0 ? 500 : limit
        }
        set {
            withMutation(keyPath: \.historyLimit) {
                UserDefaults.standard.set(newValue, forKey: historyLimitKey)
            }
        }
    }
    
    var autoCleanEnabled: Bool {
        get {
            access(keyPath: \.autoCleanEnabled)
            return UserDefaults.standard.bool(forKey: autoCleanEnabledKey)
        }
        set {
            withMutation(keyPath: \.autoCleanEnabled) {
                UserDefaults.standard.set(newValue, forKey: autoCleanEnabledKey)
            }
        }
    }
    
    var autoCleanDays: Int {
        get {
            access(keyPath: \.autoCleanDays)
            let days = UserDefaults.standard.integer(forKey: autoCleanDaysKey)
            return days == 0 ? 10 : days
        }
        set {
            withMutation(keyPath: \.autoCleanDays) {
                UserDefaults.standard.set(newValue, forKey: autoCleanDaysKey)
            }
        }
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

    private init() {}
}
