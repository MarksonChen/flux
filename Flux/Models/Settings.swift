import AppKit

struct AppSettings: Codable {
    var fontFamily: String = "SF Pro"
    var fontSize: CGFloat = 36
    var textColorHex: String = "#FFFFFF"
    var opacity: CGFloat = 0.5
    var shadowEnabled: Bool = false
    var maxHistoryEntries: Int = 20
    var launchAtLogin: Bool = false

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

    var leftClickAction: MouseAction = .togglePauseResume
    var rightClickAction: MouseAction = .reset

    enum MouseAction: String, Codable, CaseIterable {
        case togglePauseResume = "Toggle Pause/Resume"
        case reset = "Reset"
        case none = "None"
    }

    static let `default` = ShortcutBindings()
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
