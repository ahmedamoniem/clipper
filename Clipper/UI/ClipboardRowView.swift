import SwiftUI

struct ClipboardRowView: View {
    let item: ClipboardItem

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
        }
        .padding(.vertical, 4)
    }

    private func appIcon(for bundleId: String) -> NSImage? {
        if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.path {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
}
