import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let fullText: String
    let timestamp: Date
    let sourceAppBundleId: String?
    var isPinned: Bool

    init(id: UUID, fullText: String, timestamp: Date, sourceAppBundleId: String? = nil, isPinned: Bool = false) {
        self.id = id
        self.fullText = fullText
        self.timestamp = timestamp
        self.sourceAppBundleId = sourceAppBundleId
        self.isPinned = isPinned
    }

    var previewText: String {
        ClipboardItem.makePreview(from: fullText)
    }

    static func makePreview(from text: String, maxLength: Int = 500) -> String {
        let condensed = text.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        if condensed.count <= maxLength {
            return condensed
        }
        let index = condensed.index(condensed.startIndex, offsetBy: maxLength)
        return String(condensed[..<index])
    }
}
