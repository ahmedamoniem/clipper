import SwiftUI
import Carbon


struct HotkeyPreferencesView: View {
    @State private var selectedTab: PreferenceTab = .hotkey
    
    enum PreferenceTab: String, CaseIterable, Identifiable {
        case hotkey = "Hotkey"
        case general = "General"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .hotkey: return "keyboard"
            case .general: return "gearshape"
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
                case .hotkey:
                    if #available(macOS 14.0, *) {
                        HotkeyTab()
                    } else {
                        // Fallback on earlier versions
                    }
                case .general:
                    GeneralTab()
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
                    Label("Requires Accessibility permission in System Settings", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
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
