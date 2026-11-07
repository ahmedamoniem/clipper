import SwiftUI

@available(macOS 14.0, *)
struct ClipboardPopupView: View {
    var store: ClipboardStore
    @Bindable var viewModel: PopupViewModel
    let onSelect: (ClipboardItem) -> Void
    let onClose: () -> Void

    private enum SectionID: Hashable {
        case pinned
        case recent
    }

    private var filteredItems: [ClipboardItem] {
        store.filteredItems(query: viewModel.searchText)
    }

    private var pinnedItems: [ClipboardItem] {
        filteredItems.filter { $0.isPinned }
    }
    
    private var recentItems: [ClipboardItem] {
        filteredItems.filter { !$0.isPinned }
    }

    private var combinedItems: [ClipboardItem] {
        pinnedItems + recentItems
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                SearchFieldView(
                    text: $viewModel.searchText,
                    focusToken: viewModel.focusToken,
                    onMove: handleMove,
                    onEnter: selectCurrent,
                    onEscape: onClose
                )
                
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.showSettings.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(viewModel.showSettings ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Divider()

            if filteredItems.isEmpty {
                Text("No clipboard items")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(selection: $viewModel.selectedId) {
                        if !pinnedItems.isEmpty {
                            Section {
                                ForEach(pinnedItems) { item in
                                    ClipboardRowView(item: item)
                                        .tag(item.id)
                                        .id(item.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewModel.selectedId = item.id
                                            onSelect(item)
                                        }
                                }
                            } header: {
                                Text("Pinned")
                                    .id(SectionID.pinned)
                            }
                        }
                        
                        Section {
                            ForEach(recentItems) { item in
                                ClipboardRowView(item: item)
                                    .tag(item.id)
                                    .id(item.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.selectedId = item.id
                                        onSelect(item)
                                    }
                            }
                        } header: {
                            Text("Recent")
                                .id(SectionID.recent)
                        }
                    }
                    .listStyle(.inset)
                    .onChange(of: viewModel.selectedId) { _, newId in
                        if let newId {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                scrollToSelection(newId, using: proxy)
                            }
                        }
                    }
                    .onChange(of: viewModel.focusToken) { _, _ in
                        if let selectedId = viewModel.selectedId {
                            scrollToSelection(selectedId, using: proxy)
                        }
                    }
                    .onAppear {
                        if let selectedId = viewModel.selectedId {
                            scrollToSelection(selectedId, using: proxy)
                        }
                    }
                }
            }

            if let error = store.persistenceError {
                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 12)
            }
            if viewModel.showSettings || (store.settings.autoPasteEnabled && !viewModel.isTrusted) {
                Divider()
                footerView
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 360, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .onMoveCommand { direction in
            handleMove(direction)
        }
        .onExitCommand {
            onClose()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Self-healing: refresh trust status reactively when user returns to app
            viewModel.refreshTrustStatus()
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.selectedId = recentItems.first?.id ?? pinnedItems.first?.id
        }
        .onChange(of: filteredItems.map(\.id)) { _, ids in
            if !ids.contains(where: { $0 == viewModel.selectedId }) {
                viewModel.selectedId = recentItems.first?.id ?? pinnedItems.first?.id
            }
        }
        .background(hiddenActions)
    }

    private func scrollToSelection(_ id: ClipboardItem.ID, using proxy: ScrollViewProxy) {
        // Align the header, not its first row, so the floating header cannot cover the selection.
        if id == recentItems.first?.id {
            proxy.scrollTo(SectionID.recent, anchor: .top)
        } else if id == pinnedItems.first?.id {
            proxy.scrollTo(SectionID.pinned, anchor: .top)
        } else {
            proxy.scrollTo(id, anchor: .none)
        }
    }

    private var footerView: some View {
        VStack(spacing: 10) {
            HStack {
                if store.settings.autoPasteEnabled && !viewModel.isTrusted {
                    Button {
                        NSApp.sendAction(#selector(AppDelegate.showAccessibilityGuide), to: nil, from: nil)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                            Text("Enable Auto-Paste on Enter")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .help("Requires Accessibility permission to paste into other apps.")
                } else {
                    Text(store.settings.autoPasteEnabled ? "Auto-Paste is active" : "Auto-Paste is off")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("⌘P to pin")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Text("⌘W to close")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.showSettings {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("History Size:")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("\(AppSettings.shared.historyLimit) clips")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    
                    Slider(value: sliderBinding, in: 10...1000, step: 10)
                        .controlSize(.small)
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(AppSettings.shared.historyLimit) },
            set: { AppSettings.shared.historyLimit = Int($0) }
        )
    }

    private var hiddenActions: some View {
        VStack {
            Button("Select", action: selectCurrent)
                .keyboardShortcut(.defaultAction)
            Button("Close", action: onClose)
                .keyboardShortcut("w", modifiers: .command)
            Button("Toggle Pin") {
                if let id = viewModel.selectedId {
                    store.togglePin(id: id)
                }
            }
            .keyboardShortcut("p", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        let items = combinedItems
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
            onSelect(item)
            return
        }

        if let first = filteredItems.first {
            onSelect(first)
        }
    }
}

