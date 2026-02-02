import AppKit
import ServiceManagement

protocol SettingsWindowDelegate: AnyObject {
    func settingsDidChange()
}

final class SettingsWindowController: NSWindowController, NSTabViewDelegate {
    weak var delegate: SettingsWindowDelegate?

    private var tabView: NSTabView!

    private var fontPopup: NSPopUpButton!
    private var fontSizeSlider: NSSlider!
    private var fontSizeLabel: NSTextField!
    private var colorWell: NSColorWell!
    private var opacitySlider: NSSlider!
    private var opacityLabel: NSTextField!
    private var shadowCheckbox: NSButton!

    private var maxHistoryField: NSTextField!
    private var launchAtLoginCheckbox: NSButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()

        self.init(window: window)
        setupUI()
        loadSettings()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.delegate = self
        contentView.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])

        setupAppearanceTab()
        setupShortcutsTab()
        setupHistoryTab()
        setupGeneralTab()
    }

    private func setupAppearanceTab() {
        let tabItem = NSTabViewItem(identifier: "appearance")
        tabItem.label = "Appearance"

        let view = NSView()
        tabItem.view = view

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        let fontRow = NSStackView()
        fontRow.orientation = .horizontal
        fontRow.spacing = 10
        let fontLabel = NSTextField(labelWithString: "Font:")
        fontLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        fontPopup = NSPopUpButton()
        fontPopup.target = self
        fontPopup.action = #selector(fontChanged)
        populateFonts()
        fontRow.addArrangedSubview(fontLabel)
        fontRow.addArrangedSubview(fontPopup)
        stack.addArrangedSubview(fontRow)

        let sizeRow = NSStackView()
        sizeRow.orientation = .horizontal
        sizeRow.spacing = 10
        let sizeLabel = NSTextField(labelWithString: "Size:")
        sizeLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        fontSizeSlider = NSSlider(value: 36, minValue: 12, maxValue: 120, target: self, action: #selector(fontSizeChanged))
        fontSizeSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        fontSizeLabel = NSTextField(labelWithString: "36pt")
        sizeRow.addArrangedSubview(sizeLabel)
        sizeRow.addArrangedSubview(fontSizeSlider)
        sizeRow.addArrangedSubview(fontSizeLabel)
        stack.addArrangedSubview(sizeRow)

        let colorRow = NSStackView()
        colorRow.orientation = .horizontal
        colorRow.spacing = 10
        let colorLabel = NSTextField(labelWithString: "Color:")
        colorLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        colorWell = NSColorWell()
        colorWell.color = .white
        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        colorRow.addArrangedSubview(colorLabel)
        colorRow.addArrangedSubview(colorWell)
        stack.addArrangedSubview(colorRow)

        let opacityRow = NSStackView()
        opacityRow.orientation = .horizontal
        opacityRow.spacing = 10
        let opLabel = NSTextField(labelWithString: "Opacity:")
        opLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        opacitySlider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: self, action: #selector(opacityChanged))
        opacitySlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        opacityLabel = NSTextField(labelWithString: "50%")
        opacityRow.addArrangedSubview(opLabel)
        opacityRow.addArrangedSubview(opacitySlider)
        opacityRow.addArrangedSubview(opacityLabel)
        stack.addArrangedSubview(opacityRow)

        shadowCheckbox = NSButton(checkboxWithTitle: "Drop Shadow", target: self, action: #selector(shadowChanged))
        stack.addArrangedSubview(shadowCheckbox)

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetAppearance))
        stack.addArrangedSubview(resetButton)

        tabView.addTabViewItem(tabItem)
    }

    private func populateFonts() {
        fontPopup.removeAllItems()
        fontPopup.addItem(withTitle: "SF Pro")

        let fontFamilies = NSFontManager.shared.availableFontFamilies.sorted()
        for family in fontFamilies {
            if family != "SF Pro" {
                fontPopup.addItem(withTitle: family)
            }
        }
    }

    private func setupShortcutsTab() {
        let tabItem = NSTabViewItem(identifier: "shortcuts")
        tabItem.label = "Shortcuts"

        let view = NSView()
        tabItem.view = view

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        let infoLabel = NSTextField(labelWithString: "Keyboard shortcuts:")
        infoLabel.font = NSFont.boldSystemFont(ofSize: 12)
        stack.addArrangedSubview(infoLabel)

        let shortcuts = [
            "Space - Toggle pause/resume",
            "⌘C - Copy time in minutes",
            "⌘S - Set time",
            "⌘Y - History",
            "⌘, - Settings",
            "⌘Q - Quit"
        ]

        for shortcut in shortcuts {
            let label = NSTextField(labelWithString: shortcut)
            stack.addArrangedSubview(label)
        }

        let mouseLabel = NSTextField(labelWithString: "\nMouse actions:")
        mouseLabel.font = NSFont.boldSystemFont(ofSize: 12)
        stack.addArrangedSubview(mouseLabel)

        let mouseActions = [
            "Left-click - Toggle pause/resume",
            "Right-click - Reset",
            "Drag - Reposition window"
        ]

        for action in mouseActions {
            let label = NSTextField(labelWithString: action)
            stack.addArrangedSubview(label)
        }

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetShortcuts))
        stack.addArrangedSubview(resetButton)

        tabView.addTabViewItem(tabItem)
    }

    private func setupHistoryTab() {
        let tabItem = NSTabViewItem(identifier: "history")
        tabItem.label = "History"

        let view = NSView()
        tabItem.view = view

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        let maxRow = NSStackView()
        maxRow.orientation = .horizontal
        maxRow.spacing = 10
        let maxLabel = NSTextField(labelWithString: "Maximum entries:")
        maxHistoryField = NSTextField()
        maxHistoryField.stringValue = "20"
        maxHistoryField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        maxHistoryField.target = self
        maxHistoryField.action = #selector(maxHistoryChanged)

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 1000
        maxHistoryField.formatter = formatter

        maxRow.addArrangedSubview(maxLabel)
        maxRow.addArrangedSubview(maxHistoryField)
        stack.addArrangedSubview(maxRow)

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetHistory))
        stack.addArrangedSubview(resetButton)

        tabView.addTabViewItem(tabItem)
    }

    private func setupGeneralTab() {
        let tabItem = NSTabViewItem(identifier: "general")
        tabItem.label = "General"

        let view = NSView()
        tabItem.view = view

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(launchAtLoginChanged))
        stack.addArrangedSubview(launchAtLoginCheckbox)

        tabView.addTabViewItem(tabItem)
    }

    private func loadSettings() {
        let settings = Persistence.shared.appSettings

        fontPopup.selectItem(withTitle: settings.fontFamily)
        fontSizeSlider.doubleValue = Double(settings.fontSize)
        fontSizeLabel.stringValue = "\(Int(settings.fontSize))pt"
        colorWell.color = settings.textColor
        opacitySlider.doubleValue = Double(settings.opacity * 100)
        opacityLabel.stringValue = "\(Int(settings.opacity * 100))%"
        shadowCheckbox.state = settings.shadowEnabled ? .on : .off
        maxHistoryField.stringValue = "\(settings.maxHistoryEntries)"
        launchAtLoginCheckbox.state = settings.launchAtLogin ? .on : .off
    }

    @objc private func fontChanged() {
        var settings = Persistence.shared.appSettings
        settings.fontFamily = fontPopup.titleOfSelectedItem ?? "SF Pro"
        Persistence.shared.appSettings = settings
        delegate?.settingsDidChange()
    }

    @objc private func fontSizeChanged() {
        var settings = Persistence.shared.appSettings
        settings.fontSize = CGFloat(fontSizeSlider.doubleValue)
        Persistence.shared.appSettings = settings
        fontSizeLabel.stringValue = "\(Int(settings.fontSize))pt"
        delegate?.settingsDidChange()
    }

    @objc private func colorChanged() {
        var settings = Persistence.shared.appSettings
        settings.textColor = colorWell.color
        Persistence.shared.appSettings = settings
        delegate?.settingsDidChange()
    }

    @objc private func opacityChanged() {
        var settings = Persistence.shared.appSettings
        settings.opacity = CGFloat(opacitySlider.doubleValue / 100)
        Persistence.shared.appSettings = settings
        opacityLabel.stringValue = "\(Int(settings.opacity * 100))%"
        delegate?.settingsDidChange()
    }

    @objc private func shadowChanged() {
        var settings = Persistence.shared.appSettings
        settings.shadowEnabled = shadowCheckbox.state == .on
        Persistence.shared.appSettings = settings
        delegate?.settingsDidChange()
    }

    @objc private func maxHistoryChanged() {
        var settings = Persistence.shared.appSettings
        settings.maxHistoryEntries = Int(maxHistoryField.stringValue) ?? 20
        Persistence.shared.appSettings = settings
    }

    @objc private func launchAtLoginChanged() {
        var settings = Persistence.shared.appSettings
        settings.launchAtLogin = launchAtLoginCheckbox.state == .on
        Persistence.shared.appSettings = settings

        if #available(macOS 13.0, *) {
            do {
                if settings.launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
            }
        }
    }

    @objc private func resetAppearance() {
        Persistence.shared.resetSettings()
        loadSettings()
        delegate?.settingsDidChange()
    }

    @objc private func resetShortcuts() {
        Persistence.shared.resetShortcuts()
    }

    @objc private func resetHistory() {
        maxHistoryField.stringValue = "20"
        var settings = Persistence.shared.appSettings
        settings.maxHistoryEntries = 20
        Persistence.shared.appSettings = settings
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
