# Clipper

A minimal macOS menu bar clipboard history app (text only). It runs in the background, tracks the last 10 text clipboard entries, and shows a searchable popup on Control+V.

**Requirements**
- macOS 13+ (Ventura)
- Xcode 14+ (Swift 5.7+)

**How to Run**
1. Open `Clipper.xcodeproj` in Xcode.
2. Select the `Clipper` scheme.
3. Run (Cmd+R).

**Hotkey**
- Control+V toggles the clipboard history popup.
- Selecting an item copies the full text back to the clipboard (paste with Cmd+V in your app).
- Optional: Enable "Auto-Paste on Enter" from the menu to paste automatically (requires Accessibility permission).

**Notes & Limitations**
- Text-only clipboard history (no images yet).
- Auto-paste is optional and disabled by default.
- History is stored locally in memory and persisted to `~/Library/Application Support/Clipper/clipboard_history.json` (not encrypted).
- You can clear stored history by deleting that file while the app is closed.
- Clicking outside the popup closes it.
 - Auto-paste uses macOS Accessibility permission and sends Cmd+V to the previously focused app.

**Future Work (Not Implemented)**
- Rich content and image support
- Auto-paste (would require Accessibility permission)
- Pin/favorite items
- Configurable hotkeys
- Sync or cloud backup


storageURLOverride
