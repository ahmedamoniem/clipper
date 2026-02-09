import SwiftUI
import Carbon

enum HotkeyFormatter {
    static func describe(keyCode: Int, modifierFlags: Int) -> String {
        var parts: [String] = []
        let carbonMods = UInt32(modifierFlags)
        
        if carbonMods & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if carbonMods & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonMods & UInt32(controlKey) != 0 { parts.append("^") }
        if carbonMods & UInt32(shiftKey) != 0 { parts.append("⇧") }
        
        if let keyString = keyName(for: keyCode) {
            parts.append(keyString)
        } else {
            parts.append(String(describing: keyCode))
        }
        
        return parts.joined(separator: " ")
    }
    
    static func convertToCarbonModifiers(_ nsModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonMods: UInt32 = 0
        if nsModifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if nsModifiers.contains(.option) { carbonMods |= UInt32(optionKey) }
        if nsModifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
        if nsModifiers.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        return carbonMods
    }
    
    private static func keyName(for keyCode: Int) -> String? {
        switch keyCode {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        default: return nil
        }
    }
}

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
                    HotkeyTab()
                case .general:
                    GeneralTab()
                }
            }
        }
        .frame(width: 700, height: 500)
    }
}

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
