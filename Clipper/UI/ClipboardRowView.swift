import SwiftUI

struct ClipboardRowView: View {
    let item: ClipboardItem
    let store: ClipboardStore?
    private static let iconCache = NSCache<NSString, NSImage>()
    @State private var thumbnailImage: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            if item.isImage {
                if let thumbnailImage {
                    Image(nsImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                }
            } else if let bundleId = item.sourceAppBundleId,
               let icon = appIcon(for: bundleId) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }

            Text(item.previewText)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .task {
            if item.isImage, thumbnailImage == nil, let store = store {
                if let imageData = store.imageData(for: item),
                   let thumbnail = ImageProcessor.generateThumbnail(from: imageData, maxSize: 40) {
                    thumbnailImage = NSImage(data: thumbnail)
                }
            }
        }
    }

    private func appIcon(for bundleId: String) -> NSImage? {
        if let cached = Self.iconCache.object(forKey: bundleId as NSString) {
            return cached
        }

        if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.path {
            let icon = NSWorkspace.shared.icon(forFile: path)
            Self.iconCache.setObject(icon, forKey: bundleId as NSString)
            return icon
        }
        return nil
    }
}
