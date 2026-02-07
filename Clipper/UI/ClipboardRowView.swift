import SwiftUI

struct ClipboardRowView: View {
    let item: ClipboardItem

    var body: some View {
        Text(item.previewText)
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
