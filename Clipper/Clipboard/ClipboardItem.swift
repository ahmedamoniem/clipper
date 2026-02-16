import Foundation

enum ClipboardContentType: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let contentType: ClipboardContentType
    let fullText: String?
    let imageFileName: String?
    let imageDimensions: CGSize?
    let timestamp: Date
    let sourceAppBundleId: String?
    var isPinned: Bool

    init(id: UUID, fullText: String, timestamp: Date, sourceAppBundleId: String? = nil, isPinned: Bool = false) {
        self.id = id
        self.contentType = .text
        self.fullText = fullText
        self.imageFileName = nil
        self.imageDimensions = nil
        self.timestamp = timestamp
        self.sourceAppBundleId = sourceAppBundleId
        self.isPinned = isPinned
    }
    
    init(id: UUID, imageFileName: String, imageDimensions: CGSize?, timestamp: Date, sourceAppBundleId: String? = nil, isPinned: Bool = false) {
        self.id = id
        self.contentType = .image
        self.fullText = nil
        self.imageFileName = imageFileName
        self.imageDimensions = imageDimensions
        self.timestamp = timestamp
        self.sourceAppBundleId = sourceAppBundleId
        self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, contentType, fullText, imageFileName, imageDimensions, timestamp, sourceAppBundleId, isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.contentType = try container.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
        self.fullText = try container.decodeIfPresent(String.self, forKey: .fullText)
        self.imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        self.imageDimensions = try container.decodeIfPresent(CGSize.self, forKey: .imageDimensions)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.sourceAppBundleId = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleId)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
    
    var isImage: Bool {
        contentType == .image
    }

    var previewText: String {
        if contentType == .image {
            if let dimensions = imageDimensions {
                return "Image (\(Int(dimensions.width))×\(Int(dimensions.height)))"
            }
            return "Image"
        }
        return ClipboardItem.makePreview(from: fullText ?? "")
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
