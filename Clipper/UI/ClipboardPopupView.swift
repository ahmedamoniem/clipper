import SwiftUI

struct ClipboardPopupView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var viewModel: PopupViewModel
    let onSelect: (ClipboardItem) -> Void
    let onClose: () -> Void

    private var filteredItems: [ClipboardItem] {
        store.filteredItems(query: viewModel.searchText)
    }

    var body: some View {
        VStack(spacing: 8) {
            SearchFieldView(
                text: $viewModel.searchText,
                focusToken: viewModel.focusToken,
                onMove: handleMove,
                onEnter: selectCurrent,
                onEscape: onClose
            )
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Divider()

            if filteredItems.isEmpty {
                Text("No clipboard items")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $viewModel.selectedId) {
                    ForEach(filteredItems) { item in
                        ClipboardRowView(item: item)
                            .contentShape(Rectangle())
                            .tag(item.id)
                            .onTapGesture {
                                viewModel.selectedId = item.id
                                select(item)
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 360, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onMoveCommand { direction in
            handleMove(direction)
        }
        .onExitCommand {
            onClose()
        }
        .background(hiddenActions)
    }

    private var hiddenActions: some View {
        VStack {
            Button("Select", action: selectCurrent)
                .keyboardShortcut(.defaultAction)
            Button("Close", action: onClose)
                .keyboardShortcut("w", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        let items = filteredItems
        guard !items.isEmpty else { return }

        let currentIndex = items.firstIndex { $0.id == viewModel.selectedId }
        switch direction {
        case .down:
            if let currentIndex {
                let nextIndex = min(currentIndex + 1, items.count - 1)
                viewModel.selectedId = items[nextIndex].id
            } else {
                viewModel.selectedId = items.first?.id
            }
        case .up:
            if let currentIndex {
                let previousIndex = max(currentIndex - 1, 0)
                viewModel.selectedId = items[previousIndex].id
            } else {
                viewModel.selectedId = items.first?.id
            }
        default:
            break
        }
    }

    private func selectCurrent() {
        if let selectedId = viewModel.selectedId,
           let item = filteredItems.first(where: { $0.id == selectedId }) {
            select(item)
            return
        }

        if let first = filteredItems.first {
            select(first)
        }
    }

    private func select(_ item: ClipboardItem) {
        onSelect(item)
    }
}
