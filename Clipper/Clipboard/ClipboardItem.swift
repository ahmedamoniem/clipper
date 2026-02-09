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

    private enum CodingKeys: String, CodingKey {
        case id, fullText, timestamp, sourceAppBundleId, isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.fullText = try container.decode(String.self, forKey: .fullText)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.sourceAppBundleId = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleId)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
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
