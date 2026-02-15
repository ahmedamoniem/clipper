import Foundation

actor ClipboardStore {
    private var items: [String] = []

    // Your existing methods here...

    func clearAllItems() {
        items.removeAll()
    }
}

// Properly wrapping the call in an async function
func resetClipboard(store: ClipboardStore) async {
    await store.clearAllItems()
}