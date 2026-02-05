import AppKit

enum Design {
    // MARK: - Corner Radius
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    // MARK: - Spacing (8pt grid system)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Opacity
    enum Opacity {
        static let subtle: CGFloat = 0.05
        static let light: CGFloat = 0.1
        static let medium: CGFloat = 0.15
        static let border: CGFloat = 0.3
    }

    // MARK: - Dimensions
    enum Size {
        static let inputFieldHeight: CGFloat = 28
        static let inputFieldWidth: CGFloat = 40
        static let buttonWidth: CGFloat = 100
        static let sliderWidth: CGFloat = 180
        static let colorWellWidth: CGFloat = 44
        static let colorWellHeight: CGFloat = 24
        static let labelWidth: CGFloat = 130
        static let tableRowHeight: CGFloat = 28
        static let shortcutFieldMinWidth: CGFloat = 80
    }

    // MARK: - Font Sizes
    enum FontSize {
        static let xs: CGFloat = 11
        static let sm: CGFloat = 12
        static let base: CGFloat = 13
        static let lg: CGFloat = 24
    }

    // MARK: - Window Sizes
    enum WindowSize {
        static let setTime = NSSize(width: 260, height: 140)
        static let history = NSSize(width: 450, height: 700)
        static let historyMin = NSSize(width: 380, height: 250)
        static let settings = NSSize(width: 480, height: 400)
        static let settingsAppearance: CGFloat = 280
        static let settingsShortcuts: CGFloat = 480
        static let settingsGeneral: CGFloat = 160
        static let timer = NSSize(width: 150, height: 60)
    }
}
