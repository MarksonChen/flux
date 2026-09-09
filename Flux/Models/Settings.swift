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

    /// A copy with only the appearance fields (font, size, color, opacity) restored to
    /// their defaults. General settings such as launch-at-login are preserved.
    func resettingAppearance() -> AppSettings {
        var copy = AppSettings.default
        copy.launchAtLogin = launchAtLogin
        copy.showInFullScreen = showInFullScreen
        return copy
    }
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

    var toggleEnabled: Bool = true
    var toggleModifiers: UInt = NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.command.rawValue
    var toggleKeyCode: UInt16 = 17  // 't' key

    static let `default` = GlobalShortcutBindings()

    /// Only these modifiers participate in matching; caps lock, fn and
    /// device-specific bits are ignored.
    static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    var copyAndResetModifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: copyAndResetModifiers).intersection(Self.relevantModifiers)
    }

    var toggleModifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: toggleModifiers).intersection(Self.relevantModifiers)
    }

    var copyAndResetDisplayString: String {
        KeyDisplay.string(keyCode: copyAndResetKeyCode, modifiers: copyAndResetModifierFlags)
    }

    var toggleDisplayString: String {
        KeyDisplay.string(keyCode: toggleKeyCode, modifiers: toggleModifierFlags)
    }
}

extension NSColor {
    /// Parses `#RRGGBB` (or the `#RGB` shorthand) into an sRGB color.
    /// Returns nil for any other shape so a corrupted preference falls back cleanly.
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        if hexSanitized.count == 3 {
            hexSanitized = hexSanitized.map { "\($0)\($0)" }.joined()
        }

        guard hexSanitized.count == 6,
              hexSanitized.allSatisfy({ $0.isHexDigit }),
              let rgb = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        // Use sRGB explicitly so the value round-trips through `hexString`
        // (which also reads sRGB components) without drifting.
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int((rgbColor.redComponent * 255).rounded())
        let g = Int((rgbColor.greenComponent * 255).rounded())
        let b = Int((rgbColor.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
