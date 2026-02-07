import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems = 10
    private let storageURLOverride: URL?
    private let saveDelay: TimeInterval
    private let saveQueue = DispatchQueue(label: "Clipper.ClipboardStore.Save", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    init(storageURL: URL? = nil, saveDelay: TimeInterval = 0.5) {
        self.storageURLOverride = storageURL
        self.saveDelay = saveDelay
        loadFromDisk()
    }

    func add(text: String) {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return }

        if let existingIndex = items.firstIndex(where: { normalize($0.fullText) == normalized }) {
            items.remove(at: existingIndex)
        }

        let item = ClipboardItem(id: UUID(), fullText: text, timestamp: Date())
        items.insert(item, at: 0)

        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        saveDebounced(snapshot: items)
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
            items = Array(decoded.prefix(maxItems))
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
