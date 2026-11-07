import AppKit
import Observation

@available(macOS 14.0, *)
@Observable
@MainActor
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []
    private(set) var persistenceError: String?
    let settings: AppSettings
    let storageURL: URL

    private let saveDelay: TimeInterval
    private let saveQueue = DispatchQueue(label: "Clipper.ClipboardStore.Save", qos: .utility)
    @ObservationIgnored private var saveWorkItem: DispatchWorkItem?
    @ObservationIgnored private var saveGeneration = 0
    @ObservationIgnored private var canSave = true
    @ObservationIgnored private var pendingClear = false

    init(storageURL: URL? = nil, saveDelay: TimeInterval = 0.5, settings: AppSettings? = nil) {
        self.settings = settings ?? .shared
        self.storageURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clipper", isDirectory: true)
            .appendingPathComponent("clipboard_history.json")
        self.saveDelay = saveDelay
        loadFromDisk()
        observeRetentionSettings()
        applyRetention()
    }

    private func observeRetentionSettings() {
        withObservationTracking {
            _ = settings.historyLimit
            _ = settings.autoCleanEnabled
            _ = settings.autoCleanDays
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.observeRetentionSettings()
                self.applyRetention()
            }
        }
    }

    func applyRetention(now: Date = Date()) {
        let originalCount = items.count
        if settings.autoCleanEnabled,
           let cutoff = Calendar.current.date(byAdding: .day, value: -settings.autoCleanDays, to: now) {
            items.removeAll { !$0.isPinned && $0.timestamp < cutoff }
        }
        pruneToLimit()
        if items.count != originalCount {
            saveDebounced()
        }
    }

    func add(text: String) {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return }
        if let index = items.firstIndex(where: { $0.fullText.map(normalize) == normalized }) {
            guard !items[index].isPinned else { return }
            items.remove(at: index)
        }
        let item = ClipboardItem(id: UUID(), fullText: text, timestamp: Date(),
                                 sourceAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        items.insert(item, at: 0)
        pruneToLimit()
        saveDebounced()
    }

    func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        applyRetention()
        saveDebounced()
    }

    /// Serialize with any running save so a stale snapshot cannot resurrect deleted clips.
    @discardableResult
    func clear() -> Bool {
        items.removeAll()
        pendingClear = true
        canSave = true // Explicit deletion also permits replacing unreadable history.
        return flush()
    }

    /// Used before termination and destructive actions; also drains earlier queued writes.
    @discardableResult
    func flush() -> Bool {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        saveGeneration += 1
        guard canSave else { return false }
        let snapshot = items
        let url = storageURL
        do {
            let clearing = pendingClear
            try saveQueue.sync {
                try Self.write(snapshot, to: url)
                if clearing { try Self.removeAuxiliaryHistory(beside: url) }
            }
            pendingClear = false
            persistenceError = nil
            return true
        } catch {
            persistenceError = "Could not save clipboard history. Changes may be lost when Clipper quits."
            return false
        }
    }

    private func pruneToLimit() {
        var recentCount = 0
        let limit = settings.historyLimit
        items.removeAll { item in
            guard !item.isPinned else { return false }
            recentCount += 1
            return recentCount > limit
        }
    }

    func filteredItems(query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.fullText?.localizedCaseInsensitiveContains(trimmed) ?? false }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            items = try JSONDecoder().decode([ClipboardItem].self, from: Data(contentsOf: storageURL))
        } catch {
            // Preserve incompatible/corrupt data before allowing a new snapshot to replace it.
            let backupURL = storageURL.appendingPathExtension("unreadable-\(UUID().uuidString)")
            do {
                try FileManager.default.moveItem(at: storageURL, to: backupURL)
                persistenceError = "Could not load history. The original file was preserved beside clipboard_history.json."
            } catch {
                canSave = false
                persistenceError = "Could not load or preserve history. Saving is disabled to protect the original file."
            }
        }
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveDebounced() {
        saveWorkItem?.cancel()
        guard canSave else { return }
        if saveDelay <= 0 || pendingClear {
            flush()
            return
        }
        saveGeneration += 1
        let generation = saveGeneration
        let snapshot = items
        let url = storageURL
        let workItem = DispatchWorkItem { [weak self] in
            let succeeded: Bool
            do {
                try Self.write(snapshot, to: url)
                succeeded = true
            } catch {
                succeeded = false
            }
            Task { @MainActor [weak self] in
                guard let self, self.saveGeneration == generation else { return }
                self.persistenceError = succeeded ? nil : "Could not save clipboard history. Changes may be lost when Clipper quits."
            }
        }
        saveWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + saveDelay, execute: workItem)
    }

    // Queue work receives only value snapshots and never reads main-actor state.
    nonisolated private static func write(_ snapshot: [ClipboardItem], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    nonisolated private static func removeAuxiliaryHistory(beside url: URL) throws {
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let files = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in files where file.lastPathComponent.hasPrefix(url.lastPathComponent + ".unreadable-")
            || file.lastPathComponent == "clipboard_images" {
            try manager.removeItem(at: file)
        }
    }

    deinit {
        saveWorkItem?.cancel()
    }
}
