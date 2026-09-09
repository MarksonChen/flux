import AppKit

/// Human-readable names for keys and modifier flags.
///
/// Shared by the shortcut recorders and the persisted binding models so every
/// place that renders a shortcut agrees on the same spelling and symbol order.
enum KeyDisplay {
    /// Modifier symbols in the canonical macOS order: ⌃ ⌥ ⇧ ⌘.
    static func symbols(for flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        return parts.joined()
    }

    /// Full shortcut string for a virtual key code plus modifiers, e.g. `⌃⌘T`.
    static func string(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        symbols(for: modifiers) + name(forKeyCode: keyCode)
    }

    /// Full shortcut string for a character-based (local) shortcut, e.g. `⌘C` or `Space`.
    static func string(character: String, requiresCommand: Bool) -> String {
        (requiresCommand ? "⌘" : "") + name(forCharacter: character)
    }

    /// Display name for a virtual key code (ANSI layout for printable keys).
    static func name(forKeyCode keyCode: UInt16) -> String {
        keyCodeNames[keyCode] ?? "Key \(keyCode)"
    }

    /// Display name for the string a key press produced (`charactersIgnoringModifiers`).
    static func name(forCharacter character: String) -> String {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return character.uppercased()
        }
        if let special = characterNames[scalar.value] {
            return special
        }
        // Function keys F1...F35 occupy a contiguous private-use range.
        let f1 = UInt32(NSF1FunctionKey)
        let f35 = UInt32(NSF35FunctionKey)
        if (f1...f35).contains(scalar.value) {
            return "F\(scalar.value - f1 + 1)"
        }
        return character.uppercased()
    }

    // MARK: - Tables

    private static let characterNames: [UInt32: String] = [
        0x20: "Space",
        0x09: "Tab",
        0x0D: "Return",
        0x03: "Enter",
        0x7F: "Delete",
        0x1B: "Escape",
        0x19: "Tab",                                  // Backtab (Shift+Tab)
        UInt32(NSUpArrowFunctionKey): "↑",
        UInt32(NSDownArrowFunctionKey): "↓",
        UInt32(NSLeftArrowFunctionKey): "←",
        UInt32(NSRightArrowFunctionKey): "→",
        UInt32(NSDeleteFunctionKey): "Forward Delete",
        UInt32(NSHomeFunctionKey): "Home",
        UInt32(NSEndFunctionKey): "End",
        UInt32(NSPageUpFunctionKey): "Page Up",
        UInt32(NSPageDownFunctionKey): "Page Down",
        UInt32(NSHelpFunctionKey): "Help",
        UInt32(NSClearLineFunctionKey): "Clear",
        UInt32(NSInsertFunctionKey): "Insert"
    ]

    private static let keyCodeNames: [UInt16: String] = [
        // Letters
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I",
        38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q",
        15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
        // Digits
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
        // Punctuation
        10: "§", 24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\",
        43: ",", 44: "/", 47: ".", 50: "`",
        // Control keys
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
        71: "Clear", 76: "Enter", 114: "Help", 115: "Home", 116: "Page Up",
        117: "Forward Delete", 119: "End", 121: "Page Down",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        // Keypad
        65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 75: "Keypad /", 78: "Keypad -",
        81: "Keypad =", 82: "Keypad 0", 83: "Keypad 1", 84: "Keypad 2", 85: "Keypad 3",
        86: "Keypad 4", 87: "Keypad 5", 88: "Keypad 6", 89: "Keypad 7", 91: "Keypad 8",
        92: "Keypad 9",
        // Function keys
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
        100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13",
        107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]
}
