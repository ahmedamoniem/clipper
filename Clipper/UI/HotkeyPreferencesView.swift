import SwiftUI
import Carbon


struct HotkeyPreferencesView: View {
    let store: ClipboardStore
    let hotkeyManager: HotkeyManager
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
                    GeneralTab(settings: store.settings)
                case .hotkey:
                    HotkeyTab(manager: hotkeyManager, settings: store.settings)
                case .storage:
                    StorageTab(store: store)
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
    let manager: HotkeyManager
    let settings: AppSettings
    @State private var keyCode: Int
    @State private var modifierFlags: Int

    init(manager: HotkeyManager, settings: AppSettings) {
        self.manager = manager
        self.settings = settings
        _keyCode = State(initialValue: settings.hotkeyKeyCode)
        _modifierFlags = State(initialValue: settings.hotkeyModifierFlags)
    }
    @State private var isListening = false

    var body: some View {
        Form {
            if let error = manager.registrationError {
                Text(error).foregroundStyle(.red)
            }
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
                            if !isListening { manager.registerCurrentSettings(settings: settings) }
                        }
                        .controlSize(.small)
                        
                        Button("Reset") {
                            isListening = false
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
        .background(HotkeyCaptureView(isActive: isListening, onCaptured: { newKey, newMods in
            keyCode = newKey
            modifierFlags = newMods
            isListening = false
            saveHotkey()
        }, onCancel: { isListening = false; manager.registerCurrentSettings(settings: settings) }))
        .onChange(of: isListening) { _, listening in
            if listening { manager.unregister() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            if isListening {
                isListening = false
                manager.registerCurrentSettings(settings: settings)
            }
        }
        .onDisappear {
            isListening = false
            manager.registerCurrentSettings(settings: settings, preservingError: true)
        }
    }

    private func saveHotkey() {
        if manager.register(keyCode: keyCode, modifierFlags: modifierFlags) {
            settings.hotkeyKeyCode = keyCode
            settings.hotkeyModifierFlags = modifierFlags
        } else {
            manager.registerCurrentSettings(settings: settings, preservingError: true)
            keyCode = settings.hotkeyKeyCode
            modifierFlags = settings.hotkeyModifierFlags
        }
    }
}

struct GeneralTab: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-paste on Enter", isOn: $settings.autoPasteEnabled)
            } header: {
                Text("Clipboard Behavior")
            } footer: {
                if settings.autoPasteEnabled {
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
        .onChange(of: settings.autoPasteEnabled) { _, enabled in
            if enabled { AutoPaste.requestPermission() }
            else { AutoPaste.cancelPendingPaste() }
        }
        .navigationTitle("General")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct StorageTab: View {
    let store: ClipboardStore
    @State private var showingAlert = false
    @State private var fileSize = "Calculating..."
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Total Size:") {
                    Text(fileSize).foregroundStyle(.secondary)
                }
                LabeledContent("Items:") {
                    Text("\(store.items.count)").foregroundStyle(.secondary)
                }
                if let error = store.persistenceError {
                    Text(error).foregroundStyle(.red)
                }

                Button("Clear History") {
                    showingAlert = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } header: {
                Text("Clipboard History")
            } footer: {
                Text("History stored at ~/Library/Application Support/Clipper/")
            }
            
            Section {
                Toggle(
                    "Auto-clean old clips",
                    isOn: Binding(
                        get: { store.settings.autoCleanEnabled },
                        set: { store.settings.autoCleanEnabled = $0 }
                    )
                )
                
                if store.settings.autoCleanEnabled {
                    HStack {
                        Text("Delete clips older than")
                        Stepper(
                            "\(store.settings.autoCleanDays)",
                            value: Binding(
                                get: { store.settings.autoCleanDays },
                                set: { store.settings.autoCleanDays = $0 }
                            ),
                            in: 1...365
                        )
                        Text(store.settings.autoCleanDays == 1 ? "day" : "days")
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
        .onAppear { updateFileSize() }
        .alert("Clear History?", isPresented: $showingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                store.clear()
                updateFileSize()
            }
        } message: {
            Text("This will permanently delete all clipboard history. This action cannot be undone.")
        }
    }
    
    private func updateFileSize() {
        let directory = store.storageURL.deletingLastPathComponent()
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys)
        var bytes: Int64 = 0
        if let files {
            for case let file as URL in files {
                if let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true {
                    bytes += Int64(values.fileSize ?? 0)
                }
            }
        }
        fileSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
