import SwiftUI

struct ClipboardRowView: View {
    let item: ClipboardItem
    private static let iconCache = NSCache<NSString, NSImage>()

    var body: some View {
        HStack(spacing: 10) {
            if let bundleId = item.sourceAppBundleId,
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
