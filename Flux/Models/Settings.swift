import AppKit

struct AppSettings: Codable {
    var fontFamily: String = "Arial Black"
    var fontSize: CGFloat = 32
    var textColorHex: String = "#5DFFFF"
    var opacity: CGFloat = 0.40
    var launchAtLogin: Bool = false
    var showInFullScreen: Bool = false

    var textColor: NSColor {
        get {
            NSColor(hex: textColorHex) ?? .white
        }
        set {
            textColorHex = newValue.hexString
        }
    }

    static let `default` = AppSettings()
}

struct ShortcutBindings: Codable {
    var togglePauseResume: String = " "
    var copyTime: String = "c"
    var openSetTime: String = "s"
    var openHistory: String = "y"
    var openSettings: String = ","
    var quit: String = "q"

    var leftClickAction: MouseAction = .none
    var rightClickAction: MouseAction = .reset
    var leftDoubleClickAction: MouseAction = .none
    var rightDoubleClickAction: MouseAction = .none

    enum MouseAction: String, Codable, CaseIterable {
        case togglePauseResume = "Toggle Pause/Resume"
        case reset = "Reset"
        case none = "None"
    }

    static let `default` = ShortcutBindings()

    var allKeyboardShortcuts: [(name: String, key: String, requiresCommand: Bool)] {
        [
            ("Toggle pause/resume", togglePauseResume, false),
            ("Copy time", copyTime, true),
            ("Set time", openSetTime, true),
            ("History", openHistory, true),
            ("Settings", openSettings, true),
            ("Quit", quit, true)
        ]
    }
}

struct GlobalShortcutBindings: Codable, Equatable {
    var copyAndResetEnabled: Bool = true
    var copyAndResetModifiers: UInt = NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.shift.rawValue
    var copyAndResetKeyCode: UInt16 = 17  // 't' key

    static let `default` = GlobalShortcutBindings()

    var copyAndResetModifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: copyAndResetModifiers)
    }

    var copyAndResetDisplayString: String {
        var parts: [String] = []
        let flags = copyAndResetModifierFlags
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let keyString = keyCodeToString(copyAndResetKeyCode)
        parts.append(keyString)
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyCodeMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`", 49: "Space"
        ]
        return keyCodeMap[keyCode] ?? "?"
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
