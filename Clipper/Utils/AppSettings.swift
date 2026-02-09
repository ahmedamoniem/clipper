import SwiftUI
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()
    private let historyLimitKey = "HistoryLimit"

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

    private init() {}
}
