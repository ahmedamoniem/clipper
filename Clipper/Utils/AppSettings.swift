import Foundation

enum AppSettings {
    private static let autoPasteKey = "AutoPasteEnabled"

    static var autoPasteEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: autoPasteKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoPasteKey) }
    }
}
