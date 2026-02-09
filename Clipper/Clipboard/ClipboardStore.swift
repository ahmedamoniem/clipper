import SwiftUI
import Observation

@Observable
@MainActor
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []

    private let storageURLOverride: URL?
    private let saveDelay: TimeInterval
    private let saveQueue = DispatchQueue(label: "Clipper.ClipboardStore.Save", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    init(storageURL: URL? = nil, saveDelay: TimeInterval = 0.5) {
        self.storageURLOverride = storageURL
        self.saveDelay = saveDelay
        loadFromDisk()
        
        observeHistoryLimit()
    }

    private func observeHistoryLimit() {
        _ = withObservationTracking {
            AppSettings.shared.historyLimit
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.pruneToLimit()
                // Re-establish tracking for subsequent changes
                self?.observeHistoryLimit()
            }
        }
    }

    func add(text: String) {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return }

        // Don't remove if the existing item is pinned, just keep it
        if let existingIndex = items.firstIndex(where: { normalize($0.fullText) == normalized }) {
            if items[existingIndex].isPinned {
                // If pinned, just update its timestamp to bring it to the top of history? 
                // No, let's keep pins stable and just not add a duplicate to history.
                return 
            }
            items.remove(at: existingIndex)
        }

        let sourceAppId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let item = ClipboardItem(id: UUID(), fullText: text, timestamp: Date(), sourceAppBundleId: sourceAppId, isPinned: false)
        items.insert(item, at: 0)

        pruneToLimit()
        saveDebounced(snapshot: items)
    }

    func togglePin(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isPinned.toggle()
            // Prune if we just unpinned something while over the limit
            if !items[index].isPinned {
                pruneToLimit()
            }
            saveDebounced(snapshot: items)
        }
    }

    private func pruneToLimit() {
        let limit = AppSettings.shared.historyLimit
        
        // Count regular items (not pinned)
        let pinnedCount = items.filter { $0.isPinned }.count
        let totalAllowed = limit + pinnedCount
        
        if items.count > totalAllowed {
            // We need to remove the oldest non-pinned items
            var nonPinnedIndices = items.enumerated()
                .filter { !$0.element.isPinned }
                .map { $0.offset }
            
            if nonPinnedIndices.count > limit {
                let toRemove = nonPinnedIndices.suffix(nonPinnedIndices.count - limit)
                // Remove from highest index to lowest to avoid shifting
                for index in toRemove.sorted(by: >) {
                    items.remove(at: index)
                }
            }
        }
    }

    func filteredItems(query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.fullText.localizedCaseInsensitiveContains(trimmed) }
    }

    private func storageURL() -> URL? {
        if let storageURLOverride {
            return storageURLOverride
        }
        let fileManager = FileManager.default
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base.appendingPathComponent("Clipper", isDirectory: true)
            .appendingPathComponent("clipboard_history.json")
    }

    private func loadFromDisk() {
        guard let url = storageURL() else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            // Load everything, then let pruneToLimit handle the logic correctly
            items = decoded
            pruneToLimit()
        } catch {
            Logging.debug("Failed to load history: \(error)")
        }
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveDebounced(snapshot: [ClipboardItem]) {
        saveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.saveToDisk(snapshot: snapshot)
        }

        saveWorkItem = workItem
        let deadline = saveDelay <= 0 ? DispatchTime.now() : .now() + saveDelay
        saveQueue.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func saveToDisk(snapshot: [ClipboardItem]) {
        guard let url = storageURL() else { return }
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            Logging.debug("Failed to save history: \(error)")
        }
    }
}
