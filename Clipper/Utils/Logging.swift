enum Logging {
    static func debug(_ message: String) {
        #if DEBUG
        print("[Clipper] \(message)")
        #endif
    }
}
