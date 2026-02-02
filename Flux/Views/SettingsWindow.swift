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

    private var maxHistoryField: NSTextField!
    private var launchAtLoginCheckbox: NSButton!

    private var togglePauseResumeRecorder: ShortcutRecorderView!
    private var copyTimeRecorder: ShortcutRecorderView!
    private var openSetTimeRecorder: ShortcutRecorderView!
    private var openHistoryRecorder: ShortcutRecorderView!
    private var openSettingsRecorder: ShortcutRecorderView!
    private var quitRecorder: ShortcutRecorderView!
    private var leftClickPopup: NSPopUpButton!
    private var rightClickPopup: NSPopUpButton!

    convenience init() {
        let window = GlassWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
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
        tabView.tabViewType = .topTabsBezelBorder
        contentView.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
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
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Font row
        let fontRow = createSettingRow()
        let fontLabel = createLabel("Font")
        fontPopup = NSPopUpButton()
        fontPopup.target = self
        fontPopup.action = #selector(fontChanged)
        populateFonts()
        stylePopupButton(fontPopup)
        fontRow.addArrangedSubview(fontLabel)
        fontRow.addArrangedSubview(fontPopup)
        stack.addArrangedSubview(fontRow)

        // Size row
        let sizeRow = createSettingRow()
        let sizeLabel = createLabel("Size")
        fontSizeSlider = NSSlider(value: 36, minValue: 12, maxValue: 120, target: self, action: #selector(fontSizeChanged))
        fontSizeSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        fontSizeLabel = NSTextField(labelWithString: "36pt")
        fontSizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        fontSizeLabel.textColor = .secondaryLabelColor
        sizeRow.addArrangedSubview(sizeLabel)
        sizeRow.addArrangedSubview(fontSizeSlider)
        sizeRow.addArrangedSubview(fontSizeLabel)
        stack.addArrangedSubview(sizeRow)

        // Color row
        let colorRow = createSettingRow()
        let colorLabel = createLabel("Color")
        colorWell = NSColorWell()
        colorWell.color = .white
        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true
        colorRow.addArrangedSubview(colorLabel)
        colorRow.addArrangedSubview(colorWell)
        stack.addArrangedSubview(colorRow)

        // Opacity row
        let opacityRow = createSettingRow()
        let opLabel = createLabel("Opacity")
        opacitySlider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: self, action: #selector(opacityChanged))
        opacitySlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        opacityLabel = NSTextField(labelWithString: "50%")
        opacityLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        opacityLabel.textColor = .secondaryLabelColor
        opacityRow.addArrangedSubview(opLabel)
        opacityRow.addArrangedSubview(opacitySlider)
        opacityRow.addArrangedSubview(opacityLabel)
        stack.addArrangedSubview(opacityRow)

        // Reset button
        let resetButton = createGlassButton(title: "Reset to Defaults")
        resetButton.target = self
        resetButton.action = #selector(resetAppearance)
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

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let clipView = NSClipView()
        clipView.documentView = stack
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: clipView.topAnchor, constant: 15),
            stack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        let keyboardLabel = createSectionLabel("Keyboard Shortcuts")
        stack.addArrangedSubview(keyboardLabel)

        let bindings = Persistence.shared.shortcutBindings

        togglePauseResumeRecorder = createShortcutRow(label: "Toggle pause/resume", shortcut: bindings.togglePauseResume, requiresCommand: false, stack: stack) { [weak self] newKey in
            var bindings = Persistence.shared.shortcutBindings
            bindings.togglePauseResume = newKey
            Persistence.shared.shortcutBindings = bindings
            self?.loadShortcutBindings()
        }

        copyTimeRecorder = createShortcutRow(label: "Copy time", shortcut: bindings.copyTime, requiresCommand: true, stack: stack) { newKey in
            var bindings = Persistence.shared.shortcutBindings
            bindings.copyTime = newKey
            Persistence.shared.shortcutBindings = bindings
        }

        openSetTimeRecorder = createShortcutRow(label: "Set time", shortcut: bindings.openSetTime, requiresCommand: true, stack: stack) { newKey in
            var bindings = Persistence.shared.shortcutBindings
            bindings.openSetTime = newKey
            Persistence.shared.shortcutBindings = bindings
        }

        openHistoryRecorder = createShortcutRow(label: "History", shortcut: bindings.openHistory, requiresCommand: true, stack: stack) { newKey in
            var bindings = Persistence.shared.shortcutBindings
            bindings.openHistory = newKey
            Persistence.shared.shortcutBindings = bindings
        }

        openSettingsRecorder = createShortcutRow(label: "Settings", shortcut: bindings.openSettings, requiresCommand: true, stack: stack) { newKey in
            var bindings = Persistence.shared.shortcutBindings
            bindings.openSettings = newKey
            Persistence.shared.shortcutBindings = bindings
        }

        quitRecorder = createShortcutRow(label: "Quit", shortcut: bindings.quit, requiresCommand: true, stack: stack) { newKey in
            var bindings = Persistence.shared.shortcutBindings
            bindings.quit = newKey
            Persistence.shared.shortcutBindings = bindings
        }

        stack.addArrangedSubview(NSView()) // Spacer

        let mouseLabel = createSectionLabel("Mouse Actions")
        stack.addArrangedSubview(mouseLabel)

        let leftClickRow = createSettingRow()
        let leftLabel = createLabel("Left-click")
        leftClickPopup = NSPopUpButton()
        for action in ShortcutBindings.MouseAction.allCases {
            leftClickPopup.addItem(withTitle: action.rawValue)
        }
        leftClickPopup.selectItem(withTitle: bindings.leftClickAction.rawValue)
        leftClickPopup.target = self
        leftClickPopup.action = #selector(leftClickChanged)
        stylePopupButton(leftClickPopup)
        leftClickRow.addArrangedSubview(leftLabel)
        leftClickRow.addArrangedSubview(leftClickPopup)
        stack.addArrangedSubview(leftClickRow)

        let rightClickRow = createSettingRow()
        let rightLabel = createLabel("Right-click")
        rightClickPopup = NSPopUpButton()
        for action in ShortcutBindings.MouseAction.allCases {
            rightClickPopup.addItem(withTitle: action.rawValue)
        }
        rightClickPopup.selectItem(withTitle: bindings.rightClickAction.rawValue)
        rightClickPopup.target = self
        rightClickPopup.action = #selector(rightClickChanged)
        stylePopupButton(rightClickPopup)
        rightClickRow.addArrangedSubview(rightLabel)
        rightClickRow.addArrangedSubview(rightClickPopup)
        stack.addArrangedSubview(rightClickRow)

        let dragLabel = NSTextField(labelWithString: "Drag to reposition window")
        dragLabel.textColor = .tertiaryLabelColor
        dragLabel.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(dragLabel)

        stack.addArrangedSubview(NSView()) // Spacer

        let resetButton = createGlassButton(title: "Reset to Defaults")
        resetButton.target = self
        resetButton.action = #selector(resetShortcuts)
        stack.addArrangedSubview(resetButton)

        tabView.addTabViewItem(tabItem)
    }

    private func createShortcutRow(label: String, shortcut: String, requiresCommand: Bool, stack: NSStackView, onChange: @escaping (String) -> Void) -> ShortcutRecorderView {
        let row = createSettingRow()

        let labelField = createLabel(label)

        let recorder = ShortcutRecorderView()
        recorder.shortcut = shortcut
        recorder.requiresCommand = requiresCommand
        recorder.onShortcutChanged = onChange

        row.addArrangedSubview(labelField)
        row.addArrangedSubview(recorder)
        stack.addArrangedSubview(row)

        return recorder
    }

    private func loadShortcutBindings() {
        let bindings = Persistence.shared.shortcutBindings
        togglePauseResumeRecorder.shortcut = bindings.togglePauseResume
        copyTimeRecorder.shortcut = bindings.copyTime
        openSetTimeRecorder.shortcut = bindings.openSetTime
        openHistoryRecorder.shortcut = bindings.openHistory
        openSettingsRecorder.shortcut = bindings.openSettings
        quitRecorder.shortcut = bindings.quit
        leftClickPopup.selectItem(withTitle: bindings.leftClickAction.rawValue)
        rightClickPopup.selectItem(withTitle: bindings.rightClickAction.rawValue)
    }

    @objc private func leftClickChanged() {
        guard let title = leftClickPopup.titleOfSelectedItem,
              let action = ShortcutBindings.MouseAction(rawValue: title) else { return }
        var bindings = Persistence.shared.shortcutBindings
        bindings.leftClickAction = action
        Persistence.shared.shortcutBindings = bindings
    }

    @objc private func rightClickChanged() {
        guard let title = rightClickPopup.titleOfSelectedItem,
              let action = ShortcutBindings.MouseAction(rawValue: title) else { return }
        var bindings = Persistence.shared.shortcutBindings
        bindings.rightClickAction = action
        Persistence.shared.shortcutBindings = bindings
    }

    private func setupHistoryTab() {
        let tabItem = NSTabViewItem(identifier: "history")
        tabItem.label = "History"

        let view = NSView()
        tabItem.view = view

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        let maxRow = createSettingRow()
        let maxLabel = createLabel("Maximum entries")
        maxHistoryField = NSTextField()
        maxHistoryField.stringValue = "20"
        maxHistoryField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        maxHistoryField.alignment = .center
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

        let resetButton = createGlassButton(title: "Reset to Defaults")
        resetButton.target = self
        resetButton.action = #selector(resetHistory)
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
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(launchAtLoginChanged))
        launchAtLoginCheckbox.font = NSFont.systemFont(ofSize: 13)
        stack.addArrangedSubview(launchAtLoginCheckbox)

        tabView.addTabViewItem(tabItem)
    }

    // MARK: - Helper Methods

    private func createSettingRow() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.widthAnchor.constraint(equalToConstant: 130).isActive = true
        return label
    }

    private func createSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func stylePopupButton(_ button: NSPopUpButton) {
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 12)
    }

    private func createGlassButton(title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 12)
        return button
    }

    private func loadSettings() {
        let settings = Persistence.shared.appSettings

        fontPopup.selectItem(withTitle: settings.fontFamily)
        fontSizeSlider.doubleValue = Double(settings.fontSize)
        fontSizeLabel.stringValue = "\(Int(settings.fontSize))pt"
        colorWell.color = settings.textColor
        opacitySlider.doubleValue = Double(settings.opacity * 100)
        opacityLabel.stringValue = "\(Int(settings.opacity * 100))%"
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
        loadShortcutBindings()
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
