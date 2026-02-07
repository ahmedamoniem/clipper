# Clipper (MVP)

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

**Notes & Limitations**
- Text-only clipboard history (no images yet).
- Does not auto-paste into the front app.
- History is stored locally in memory and persisted to `~/Library/Application Support/Clipper/clipboard_history.json` (not encrypted).
- You can clear stored history by deleting that file while the app is closed.
- Clicking outside the popup closes it.

**Future Work (Not Implemented)**
- Rich content and image support
- Auto-paste (would require Accessibility permission)
- Pin/favorite items
- Configurable hotkeys
- Sync or cloud backup
