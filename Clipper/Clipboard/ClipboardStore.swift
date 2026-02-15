import SwiftUI
import Observation

@available(macOS 14.0, *)
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
        observeClearHistory()
        observeAutoClean()
        cleanOldItems()
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
    
    private func observeClearHistory() {
        NotificationCenter.default.addObserver(forName: Notification.Name("ClearClipboardHistory"), object: nil, queue: .main) { [weak self] _ in
            self?.clearAllItems()
        }
    }
    
    private func clearAllItems() {
        // Delete all image files
        for item in items {
            if item.isImage, let fileName = item.imageFileName {
                deleteImageFile(fileName: fileName)
            }
        }
        items.removeAll()
    }
    
    private func observeAutoClean() {
        _ = withObservationTracking {
            AppSettings.shared.autoCleanEnabled
            AppSettings.shared.autoCleanDays
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.cleanOldItems()
                self?.observeAutoClean()
            }
        }
    }
    
    private func cleanOldItems() {
        guard AppSettings.shared.autoCleanEnabled else { return }
        
        let days = AppSettings.shared.autoCleanDays
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let originalCount = items.count
        let itemsToRemove = items.filter { item in
            !item.isPinned && item.timestamp < cutoffDate
        }
        
        // Delete image files for removed items
        for item in itemsToRemove {
            if item.isImage, let fileName = item.imageFileName {
                deleteImageFile(fileName: fileName)
            }
        }
        
        items.removeAll { item in
            !item.isPinned && item.timestamp < cutoffDate
        }
        
        if items.count < originalCount {
            saveDebounced(snapshot: items)
        }
    }
    
    private func observeAutoClean() {
        _ = withObservationTracking {
            AppSettings.shared.autoCleanEnabled
            AppSettings.shared.autoCleanDays
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.cleanOldItems()
                self?.observeAutoClean()
            }
        }
    }
    
    private func cleanOldItems() {
        guard AppSettings.shared.autoCleanEnabled else { return }
        
        let days = AppSettings.shared.autoCleanDays
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let originalCount = items.count
        items.removeAll { item in
            !item.isPinned && item.timestamp < cutoffDate
        }
        
        if items.count < originalCount {
            saveDebounced(snapshot: items)
        }
    }

    func add(text: String) {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return }

        // Don't remove if the existing item is pinned, just keep it
        if let existingIndex = items.firstIndex(where: { $0.contentType == .text && normalize($0.fullText ?? "") == normalized }) {
            if items[existingIndex].isPinned {
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
    
    func add(imageData: Data) {
        let maxBytes = Int64(AppSettings.shared.maxImageSizeMB) * 1024 * 1024
        guard imageData.count <= maxBytes else {
            Logging.debug("Image too large: \(imageData.count) bytes")
            return
        }
        
        // Check for duplicate image by comparing data hash
        let imageHash = imageData.hashValue
        if let existingIndex = items.firstIndex(where: { item in
            if item.isImage, let fileName = item.imageFileName,
               let existingData = loadImageFile(fileName: fileName) {
                return existingData.hashValue == imageHash
            }
            return false
        }) {
            if items[existingIndex].isPinned {
                return
            }
            // Remove duplicate and its file
            if let fileName = items[existingIndex].imageFileName {
                deleteImageFile(fileName: fileName)
            }
            items.remove(at: existingIndex)
        }
        
        let id = UUID()
        let fileName = "\(id.uuidString).png"
        
        guard saveImageFile(data: imageData, fileName: fileName) else {
            Logging.debug("Failed to save image file")
            return
        }
        
        let dimensions = ImageProcessor.imageDimensions(from: imageData)
        let sourceAppId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let item = ClipboardItem(id: id, imageFileName: fileName, imageDimensions: dimensions, timestamp: Date(), sourceAppBundleId: sourceAppId, isPinned: false)
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
    
    func delete(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            let item = items[index]
            if item.isImage, let fileName = item.imageFileName {
                deleteImageFile(fileName: fileName)
            }
            items.remove(at: index)
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
                // Delete image files before removing items
                for index in toRemove {
                    let item = items[index]
                    if item.isImage, let fileName = item.imageFileName {
                        deleteImageFile(fileName: fileName)
                    }
                }
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
        return items.filter { 
            if $0.contentType == .text {
                return $0.fullText?.localizedCaseInsensitiveContains(trimmed) ?? false
            }
            return false
        }
    }
    
    func imageData(for item: ClipboardItem) -> Data? {
        guard item.isImage, let fileName = item.imageFileName else { return nil }
        return loadImageFile(fileName: fileName)
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
    
    private func imagesDirectoryURL() -> URL? {
        guard let storageURL = storageURL() else { return nil }
        return storageURL.deletingLastPathComponent().appendingPathComponent("clipboard_images", isDirectory: true)
    }
    
    private func saveImageFile(data: Data, fileName: String) -> Bool {
        guard let imagesDir = imagesDirectoryURL() else { return false }
        do {
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            let fileURL = imagesDir.appendingPathComponent(fileName)
            try data.write(to: fileURL, options: [.atomic])
            return true
        } catch {
            Logging.debug("Failed to save image: \(error)")
            return false
        }
    }
    
    private func loadImageFile(fileName: String) -> Data? {
        guard let imagesDir = imagesDirectoryURL() else { return nil }
        let fileURL = imagesDir.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }
    
    private func deleteImageFile(fileName: String) {
        guard let imagesDir = imagesDirectoryURL() else { return }
        let fileURL = imagesDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
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
