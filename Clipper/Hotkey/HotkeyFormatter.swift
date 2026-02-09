import Carbon
import AppKit

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
