import XCTest
@testable import Clipper

@MainActor
final class ClipboardStoreTests: XCTestCase {
    func testCappedToMaxItems() {
        withTempURL { url in
            let store = ClipboardStore(storageURL: url, saveDelay: 0)

            for i in 1...12 {
                store.add(text: "Item \(i)")
            }

            XCTAssertEqual(store.items.count, 10)
            XCTAssertEqual(store.items.first?.fullText, "Item 12")
            XCTAssertEqual(store.items.last?.fullText, "Item 3")
        }
    }

    func testNormalizationDeDuplication() {
        withTempURL { url in
            let store = ClipboardStore(storageURL: url, saveDelay: 0)

            store.add(text: "hello")
            store.add(text: "hello\n")

            XCTAssertEqual(store.items.count, 1)
            XCTAssertEqual(store.items.first?.fullText, "hello\n")
        }
    }

    func testSaveThenLoadRestoresItems() {
        withTempURL { url in
            var store: ClipboardStore? = ClipboardStore(storageURL: url, saveDelay: 0)
            store?.add(text: "first")
            store?.add(text: "second")
            store = nil

            let loadedStore = ClipboardStore(storageURL: url, saveDelay: 0)
            XCTAssertEqual(loadedStore.items.count, 2)
            XCTAssertEqual(loadedStore.items.first?.fullText, "second")
            XCTAssertEqual(loadedStore.items.last?.fullText, "first")
        }
    }

    func testCorruptedJSONFailsGracefully() {
        withTempURL { url in
            try? "not-json".data(using: .utf8)?.write(to: url, options: [.atomic])

            let store = ClipboardStore(storageURL: url, saveDelay: 0)
            XCTAssertTrue(store.items.isEmpty)
        }
    }

    func testFilteredItemsEmptyQueryReturnsAll() {
        withTempURL { url in
            let store = ClipboardStore(storageURL: url, saveDelay: 0)
            store.add(text: "Alpha")
            store.add(text: "Beta")

            let results = store.filteredItems(query: "   \n")
            XCTAssertEqual(results.count, 2)
        }
    }

    func testFilteredItemsIsCaseInsensitive() {
        withTempURL { url in
            let store = ClipboardStore(storageURL: url, saveDelay: 0)
            store.add(text: "Hello World")

            let results = store.filteredItems(query: "hello")
            XCTAssertEqual(results.count, 1)
        }
    }

    func testFilteredItemsTrimsWhitespace() {
        withTempURL { url in
            let store = ClipboardStore(storageURL: url, saveDelay: 0)
            store.add(text: "Gamma")

            let results = store.filteredItems(query: "  Gamma  ")
            XCTAssertEqual(results.count, 1)
        }
    }

    func testFilteredItemsMatchesFullTextBeyondPreview() {
        withTempURL { url in
            let store = ClipboardStore(storageURL: url, saveDelay: 0)
            let longText = String(repeating: "a", count: 520) + "needle"
            store.add(text: longText)

            let results = store.filteredItems(query: "needle")
            XCTAssertEqual(results.count, 1)
        }
    }

    private func withTempURL(_ body: (URL) throws -> Void) rethrows {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let filename = "clipper_test_\(UUID().uuidString).json"
        let url = directory.appendingPathComponent(filename)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }
}
