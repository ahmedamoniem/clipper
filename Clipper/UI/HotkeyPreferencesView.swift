import SwiftUI
import Carbon


struct HotkeyPreferencesView: View {
    @State private var selectedTab: PreferenceTab = .general
    
    enum PreferenceTab: String, CaseIterable, Identifiable {
        case general = "General"
        case hotkey = "Hotkey"
        case storage = "Storage"
        case about = "About"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .hotkey: return "keyboard"
            case .storage: return "internaldrive"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(PreferenceTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 200)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralTab()
                case .hotkey:
                    if #available(macOS 14.0, *) {
                        HotkeyTab()
                    } else {
                        // Fallback on earlier versions
                    }
                case .storage:
                    StorageTab()
                case .about:
                    AboutTab()
                }
            }
        }
        .frame(width: 700, height: 500)
    }
}

@available(macOS 14.0, *)
struct HotkeyTab: View {
    @State private var keyCode: Int = AppSettings.hotkeyKeyCode
    @State private var modifierFlags: Int = AppSettings.hotkeyModifierFlags
    @State private var isListening = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Shortcut:") {
                    HStack(spacing: 12) {
                        Text(HotkeyFormatter.describe(keyCode: keyCode, modifierFlags: modifierFlags))
                            .font(.system(.body, design: .monospaced))
                            .frame(minWidth: 80)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )
                        
                        Button(isListening ? "Recording..." : "Record") {
                            isListening.toggle()
                        }
                        .controlSize(.small)
                        
                        Button("Reset") {
                            keyCode = 9
                            modifierFlags = Int(controlKey)
                            saveHotkey()
                        }
                        .controlSize(.small)
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Clipboard History")
            } footer: {
                Text("Click Record and press your desired key combination (e.g., ⌘V or ^C)")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Hotkey")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HotkeyCaptureView(isActive: isListening) { newKey, newMods in
            keyCode = newKey
            modifierFlags = newMods
            isListening = false
            saveHotkey()
        })
    }
    
    private func saveHotkey() {
        AppSettings.hotkeyKeyCode = keyCode
        AppSettings.hotkeyModifierFlags = modifierFlags
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
    }
}

struct GeneralTab: View {
    @AppStorage("AutoPasteEnabled") private var autoPasteEnabled = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-paste on Enter", isOn: $autoPasteEnabled)
            } header: {
                Text("Clipboard Behavior")
            } footer: {
                if autoPasteEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Requires Accessibility permission in System Settings", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Button("Open Accessibility Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                        .controlSize(.small)
                    }
                } else {
                    if autoPasteEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Requires Accessibility permission in System Settings", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Button("Open Accessibility Settings") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }
                            .controlSize(.small)
                        }
                    } else {
                    Text("Automatically paste the selected item when pressing Enter")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct StorageTab: View {
    @State private var fileSize: String = "Calculating..."
    @State private var showingAlert = false
    @State private var autoCleanEnabled = AppSettings.shared.autoCleanEnabled
    @State private var autoCleanDays = AppSettings.shared.autoCleanDays
    
    var body: some View {
        Form {
            Section {
                LabeledContent("File Size:") {
                    Text(fileSize)
                        .foregroundStyle(.secondary)
                }
                
                Button("Clear History") {
                    showingAlert = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } header: {
                Text("Clipboard History")
            } footer: {
                Text("History is stored at ~/Library/Application Support/Clipper/clipboard_history.json")
            }
            
            Section {
                Toggle("Auto-clean old clips", isOn: $autoCleanEnabled)
                    .onChange(of: autoCleanEnabled) { _, newValue in
                        AppSettings.shared.autoCleanEnabled = newValue
                    }
                
                if autoCleanEnabled {
                    HStack {
                        Text("Delete clips older than")
                        Stepper("\(autoCleanDays)", value: $autoCleanDays, in: 1...365)
                            .onChange(of: autoCleanDays) { _, newValue in
                                AppSettings.shared.autoCleanDays = newValue
                            }
                        Text(autoCleanDays == 1 ? "day" : "days")
                    }
                }
            } header: {
                Text("Auto-Clean")
            } footer: {
                Text("Automatically remove clipboard items older than the specified number of days (pinned items are never deleted)")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Storage")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            updateFileSize()
        }
        .alert("Clear History?", isPresented: $showingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("This will permanently delete all clipboard history. This action cannot be undone.")
        }
    }
    
    private func updateFileSize() {
        let fileManager = FileManager.default
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fileSize = "Unknown"
            return
        }
        let url = base.appendingPathComponent("Clipper", isDirectory: true)
            .appendingPathComponent("clipboard_history.json")
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            } else {
                fileSize = "Unknown"
            }
        } catch {
            fileSize = "0 bytes"
        }
    }
    
    private func clearHistory() {
        let fileManager = FileManager.default
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let url = base.appendingPathComponent("Clipper", isDirectory: true)
            .appendingPathComponent("clipboard_history.json")
        
        try? fileManager.removeItem(at: url)
        NotificationCenter.default.post(name: Notification.Name("ClearClipboardHistory"), object: nil)
        updateFileSize()
    }
}

struct AboutTab: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version:") {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Application")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}
