import XCTest
import AppKit
@testable import Clipper

final class ClipboardStoreTests: XCTestCase {
    @MainActor
    func testCappedToMaxItems() {
        withTempURL { url, settings in
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            settings.historyLimit = 10

            for i in 1...12 {
                store.add(text: "Item \(i)")
            }

            XCTAssertEqual(store.items.count, 10)
            XCTAssertEqual(store.items.first?.fullText, "Item 12")
            XCTAssertEqual(store.items.last?.fullText, "Item 3")
        }
    }

    @MainActor
    func testNormalizationDeDuplication() {
        withTempURL { url, settings in
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)

            store.add(text: "hello")
            store.add(text: "hello\n")

            XCTAssertEqual(store.items.count, 1)
            XCTAssertEqual(store.items.first?.fullText, "hello\n")
        }
    }

    @MainActor
    func testSaveThenLoadRestoresItems() {
        withTempURL { url, settings in
            var store: ClipboardStore? = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            store?.add(text: "first")
            store?.add(text: "second")
            store = nil

            let loadedStore = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            XCTAssertEqual(loadedStore.items.count, 2)
            XCTAssertEqual(loadedStore.items.first?.fullText, "second")
            XCTAssertEqual(loadedStore.items.last?.fullText, "first")
        }
    }

    @MainActor
    func testCorruptedJSONFailsGracefully() {
        withTempURL { url, settings in
            try? "not-json".data(using: .utf8)?.write(to: url, options: [.atomic])

            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            XCTAssertTrue(store.items.isEmpty)
        }
    }

    @MainActor
    func testFilteredItemsEmptyQueryReturnsAll() {
        withTempURL { url, settings in
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            store.add(text: "Alpha")
            store.add(text: "Beta")

            let results = store.filteredItems(query: "   \n")
            XCTAssertEqual(results.count, 2)
        }
    }

    @MainActor
    func testFilteredItemsIsCaseInsensitive() {
        withTempURL { url, settings in
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            store.add(text: "Hello World")

            let results = store.filteredItems(query: "hello")
            XCTAssertEqual(results.count, 1)
        }
    }

    @MainActor
    func testFilteredItemsTrimsWhitespace() {
        withTempURL { url, settings in
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            store.add(text: "Gamma")

            let results = store.filteredItems(query: "  Gamma  ")
            XCTAssertEqual(results.count, 1)
        }
    }

    @MainActor
    func testFilteredItemsMatchesFullTextBeyondPreview() {
        withTempURL { url, settings in
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            let longText = String(repeating: "a", count: 520) + "needle"
            store.add(text: longText)

            let results = store.filteredItems(query: "needle")
            XCTAssertEqual(results.count, 1)
        }
    }

    @MainActor
    func testPinnedItemsExemptFromPruning() {
        withTempURL { url, settings in
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            settings.historyLimit = 5
            
            store.add(text: "Pin Me")
            let pinId = store.items.first!.id
            store.togglePin(id: pinId)
            
            // Add 10 more items
            for i in 1...10 {
                store.add(text: "Item \(i)")
            }
            
            // Should have 5 recent + 1 pinned = 6 total
            XCTAssertEqual(store.items.count, 6)
            XCTAssertTrue(store.items.contains(where: { $0.id == pinId }))
        }
    }

    @MainActor
    func testUnpinningTriggersPrune() {
        withTempURL { url, settings in
            settings.historyLimit = 2
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            store.add(text: "Old pin")
            let pinId = store.items[0].id
            store.togglePin(id: pinId)
            store.add(text: "Item 1")
            store.add(text: "Item 2")
            XCTAssertEqual(store.items.count, 3)

            store.togglePin(id: pinId)

            XCTAssertEqual(store.items.map(\.fullText), ["Item 2", "Item 1"])
            XCTAssertFalse(store.items.contains { $0.id == pinId })
            XCTAssertEqual(ClipboardStore(storageURL: url, settings: settings).items, store.items)
        }
    }

    @MainActor
    func testDecodingOldSchemaSafe() {
        withTempURL { url, settings in
            // JSON missing isPinned and sourceAppBundleId
            let oldJson = """
            [
                {
                    "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                    "fullText": "Old Data",
                    "timestamp": 728956800.0
                }
            ]
            """
            try? oldJson.data(using: .utf8)?.write(to: url)
            
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            XCTAssertEqual(store.items.count, 1)
            XCTAssertEqual(store.items.first?.fullText, "Old Data")
            XCTAssertFalse(store.items.first?.isPinned ?? true)
        }
    }

    func testLegacyImagePreviewHandlesInvalidDimensions() {
        for width in [CGFloat.infinity, -.infinity, .nan, -1, CGFloat(Int.max)] {
            let item = ClipboardItem(id: UUID(), imageFileName: "legacy.png",
                                     imageDimensions: CGSize(width: width, height: 10), timestamp: Date())
            XCTAssertEqual(item.previewText, "Image")
        }
    }

    @MainActor
    func testClearPersistsEmptyHistoryAndCancelsPendingSnapshot() throws {
        try withTempURL { url, settings in
            let store = ClipboardStore(storageURL: url, saveDelay: 60, settings: settings)
            store.add(text: "secret")
            store.togglePin(id: store.items[0].id)
            XCTAssertTrue(store.clear())
            XCTAssertTrue(store.items.isEmpty)
            XCTAssertTrue(try JSONDecoder().decode([ClipboardItem].self, from: Data(contentsOf: url)).isEmpty)
            XCTAssertTrue(ClipboardStore(storageURL: url, settings: settings).items.isEmpty)
        }
    }

    @MainActor
    func testClearRemovesRecoveryBackupsAndLegacyImages() throws {
        try withTempURL { url, settings in
            try Data("unreadable".utf8).write(to: url)
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            let images = url.deletingLastPathComponent().appendingPathComponent("clipboard_images")
            try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
            try Data("legacy image".utf8).write(to: images.appendingPathComponent("test.png"))
            XCTAssertTrue(store.clear())
            let remaining = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            XCTAssertEqual(remaining.map(\.lastPathComponent), [url.lastPathComponent])
        }
    }

    @MainActor
    func testFlushSavesLatestSnapshotBeforeDebounceExpires() throws {
        try withTempURL { url, settings in
            let store = ClipboardStore(storageURL: url, saveDelay: 60, settings: settings)
            store.add(text: "first")
            store.add(text: "latest")
            XCTAssertTrue(store.flush())
            let saved = try JSONDecoder().decode([ClipboardItem].self, from: Data(contentsOf: url))
            XCTAssertEqual(saved.map(\.fullText), ["latest", "first"])
        }
    }

    @MainActor
    func testRetentionChangePersistsWithoutAnotherCopy() async throws {
        let suite = "clipper-retention-test-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: url)
        }
        let settings = AppSettings(defaults: defaults)
        let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
        for i in 1...5 { store.add(text: "Item \(i)") }
        settings.historyLimit = 2
        for _ in 0..<100 where store.items.count != 2 { await Task.yield() }
        XCTAssertEqual(store.items.count, 2)
        let saved = try JSONDecoder().decode([ClipboardItem].self, from: Data(contentsOf: url))
        XCTAssertEqual(saved.count, 2)
    }

    @MainActor
    func testAutoCleanWhileRunningPreservesPinsAndPersistsDeletion() throws {
        try withTempURL { url, settings in
            let date = Date()
            let old = date.addingTimeInterval(-20 * 86400)
            let items = [ClipboardItem(id: UUID(), fullText: "pinned", timestamp: old, isPinned: true),
                         ClipboardItem(id: UUID(), fullText: "expired", timestamp: old),
                         ClipboardItem(id: UUID(), fullText: "recent", timestamp: date)]
            try JSONEncoder().encode(items).write(to: url)
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            settings.autoCleanEnabled = true
            store.applyRetention(now: date)
            XCTAssertEqual(store.items.map(\.fullText), ["pinned", "recent"])
            let saved = try JSONDecoder().decode([ClipboardItem].self, from: Data(contentsOf: url))
            XCTAssertEqual(saved, store.items)
            store.applyRetention(now: date.addingTimeInterval(11 * 86400))
            XCTAssertEqual(store.items.map(\.fullText), ["pinned"])
        }
    }

    @MainActor
    func testUnreadableHistoryIsBackedUpBeforeNewCopy() throws {
        try withTempURL { url, settings in
            let original = Data("not JSON".utf8)
            try original.write(to: url)
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            XCTAssertNotNil(store.persistenceError)
            store.add(text: "new")
            let backups = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.contains("unreadable-") }
            XCTAssertEqual(backups.count, 1)
            XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), original)
        }
    }

    @MainActor
    func testWriteFailureIsVisibleAndCanBeRetried() throws {
        try withTempURL { url, settings in
            try Data().write(to: url)
            let child = url.appendingPathComponent("history.json")
            let store = ClipboardStore(storageURL: child, saveDelay: 60, settings: settings)
            store.add(text: "keep in memory")
            XCTAssertFalse(store.flush())
            XCTAssertNotNil(store.persistenceError)
            XCTAssertEqual(store.items.count, 1)
            try FileManager.default.removeItem(at: url)
            XCTAssertTrue(store.flush())
            XCTAssertNil(store.persistenceError)
            XCTAssertEqual(ClipboardStore(storageURL: child, settings: settings).items, store.items)
        }
    }

    @MainActor
    func testUnpinExpiredItemAppliesAutoCleanImmediately() throws {
        try withTempURL { url, settings in
            settings.autoCleanEnabled = true
            let item = ClipboardItem(id: UUID(), fullText: "old pin", timestamp: Date.distantPast, isPinned: true)
            try JSONEncoder().encode([item]).write(to: url)
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            store.togglePin(id: item.id)
            XCTAssertTrue(store.items.isEmpty)
        }
    }

    @MainActor
    func testWatcherSkipsPrivateTransientAndGeneratedClipboardContents() throws {
        try withTempURL { url, settings in
            let board = NSPasteboard.withUniqueName()
            defer { board.releaseGlobally() }
            try XCTSkipUnless(board.setString("connection check", forType: .string), "Named pasteboard service is unavailable")
            let store = ClipboardStore(storageURL: url, saveDelay: 0, settings: settings)
            let watcher = ClipboardWatcher(store: store, pasteboard: board)
            for marker in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
                           "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"] {
                board.clearContents()
                board.setString("sensitive", forType: .string)
                board.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
                watcher.checkPasteboard()
                XCTAssertTrue(store.items.isEmpty, marker)
            }
            board.clearContents()
            board.setString("ordinary text", forType: .string)
            watcher.checkPasteboard()
            XCTAssertEqual(store.items.first?.fullText, "ordinary text")
            watcher.checkPasteboard()
            XCTAssertEqual(store.items.count, 1)
        }
    }

    @MainActor
    func testSettingsClampInvalidPersistedRetentionAndDefaultAutoPasteOff() {
        let suite = "clipper-settings-test-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.autoPasteEnabled)
        XCTAssertEqual(settings.historyLimit, 500)
        defaults.set(-9, forKey: "HistoryLimit")
        XCTAssertEqual(settings.historyLimit, 1)
        settings.historyLimit = Int.max
        XCTAssertEqual(settings.historyLimit, 1000)
    }

    @MainActor
    private func withTempURL(_ body: (URL, AppSettings) throws -> Void) rethrows {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("clipper-test-\(UUID())")
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "clipper-test-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        try body(directory.appendingPathComponent("history.json"), AppSettings(defaults: defaults))
    }
}
