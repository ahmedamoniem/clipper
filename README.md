# <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/clipboard-list.svg" width="32" height="32" /> Clipper

**Clipper** is a high-performance, minimal macOS menu bar utility designed to supercharge your clipboard workflow. Built with modern Swift, it focuses on speed, simplicity, and staying out of your way.

<p align="center">
  <img src="https://skillicons.dev/icons?i=swift,apple" />
</p>

---

## 🚀 Overview

Clipper tracks your clipboard history in the background, allowing you to recall text snippets instantly. No bloat, no complex UI—just your history when you need it.

[![macOS Sonoma](https://img.shields.io/badge/macOS-14.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

---

## ✨ Key Features

* **⚡ Instant Recall:** Access your last 10 text entries via `Control + V`.
* **🔍 Fuzzy Search:** Start typing to filter through your history immediately.
* **💾 Persistent:** History is saved to `~/Library/Application Support/` and survives reboots.
* **🖱️ Auto-Paste:** Optionally paste directly into the active app (requires Accessibility permissions).

---

## 🛠 Tech Stack

| Component | Technology | Logo |
| :--- | :--- | :--- |
| **Language** | Swift 5.9 | <img src="https://www.vectorlogo.zone/logos/swift/swift-icon.svg" width="20" height="20" /> |
| **Framework** | SwiftUI / AppKit | <img src="https://www.vectorlogo.zone/logos/apple/apple-icon.svg" width="20" height="20" /> |
| **Storage** | JSON (Local) | <img src="https://www.vectorlogo.zone/logos/json/json-icon.svg" width="20" height="20" /> |
| **IDE** | Xcode 15+ | <img src="https://upload.wikimedia.org/wikipedia/en/5/56/Xcode_14_icon.png" width="20" height="20" /> |

---

## ⌨️ Shortcuts & Usage

> [!TIP]
> Use the search bar to find old snippets even if they aren't in the top 3!

| Action | Shortcut |
| :--- | :--- |
| **Toggle Popup** | `Control + V` |
| **Navigate** | `Arrow Up / Down` |
| **Copy/Paste** | `Enter` |
| **Close** | `Esc` or Click Outside |

---

## 📦 Installation & Setup

1.  **Clone the Repo**
    ```bash
    git clone [[https://github.com/yourusername/Clipper.git](https://github.com/ahmedamoniem/clipper.git)t]([https://github.com/yourusername/Clipper.git](https://github.com/ahmedamoniem/clipper.git))
    ```
2.  **Open in Xcode**
    ```bash
    open Clipper.xcodeproj
    ```
3.  **Permissions**
    If using **Auto-Paste**, go to:
    `System Settings` > `Privacy & Security` > `Accessibility` and add **Clipper**.

---
## 📝 Notes & Limitations

> [!IMPORTANT]
> **Privacy & Security:** History is stored locally in **plain text (unencrypted)** at:
> `~/Library/Application Support/Clipper/clipboard_history.json`

* **🔤 Text-Only:** Currently supports text snippets only; images and rich media are not yet supported.
* **📂 Data Management:** You can clear your entire history by deleting the JSON file mentioned above while the app is closed.
* **🖱️ Popup Behavior:** The clipboard interface is designed to be non-intrusive; clicking anywhere outside the popup will automatically close it.
* **⌨️ Auto-Paste Mechanism:** This feature is **disabled by default**. When enabled, it utilizes macOS Accessibility permissions to send a `Cmd + V` command to the application that was focused before the Clipper popup appeared.

---
## 🗺 Roadmap

- [ ] <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/image.svg" width="16" height="16" /> Image & Rich Text support
- [ ] <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/lock.svg" width="16" height="16" /> Encrypted local storage
- [ ] <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/star.svg" width="16" height="16" /> Pin favorite items

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---
<p align="center">
  Made with ❤️ for macOS power users.
</p>
