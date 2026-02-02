import AppKit

final class SetTimeWindowController: NSWindowController {
    private var hoursStepper: NSTextField!
    private var minutesStepper: NSTextField!
    private var secondsStepper: NSTextField!

    private var hoursValue: Int = 0
    private var minutesValue: Int = 0
    private var secondsValue: Int = 0

    convenience init() {
        let window = GlassWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Time"
        window.center()

        self.init(window: window)
        setupUI()
        loadCurrentTime()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -30)
        ])

        let timeRow = NSStackView()
        timeRow.orientation = .horizontal
        timeRow.spacing = 8
        timeRow.alignment = .centerY

        hoursStepper = createTimeField(maxValue: 999)
        minutesStepper = createTimeField(maxValue: 59)
        secondsStepper = createTimeField(maxValue: 59)

        let hoursLabel = createUnitLabel("H")
        let minutesLabel = createUnitLabel("M")
        let secondsLabel = createUnitLabel("S")

        let colonLabel1 = createColonLabel()
        let colonLabel2 = createColonLabel()

        timeRow.addArrangedSubview(hoursStepper)
        timeRow.addArrangedSubview(hoursLabel)
//        timeRow.addArrangedSubview(colonLabel1)
        timeRow.addArrangedSubview(minutesStepper)
        timeRow.addArrangedSubview(minutesLabel)
//        timeRow.addArrangedSubview(colonLabel2)
        timeRow.addArrangedSubview(secondsStepper)
        timeRow.addArrangedSubview(secondsLabel)

        stackView.addArrangedSubview(timeRow)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        let cancelButton = createButton(title: "Cancel", isPrimary: false)
        cancelButton.target = self
        cancelButton.action = #selector(cancel)

        let setButton = createButton(title: "Set Time", isPrimary: true)
        setButton.target = self
        setButton.action = #selector(setTime)
        setButton.keyEquivalent = "\r"

        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(setButton)

        stackView.addArrangedSubview(buttonRow)
    }

    private func createTimeField(maxValue: Int) -> NSTextField {
        let field = NSTextField()
        field.stringValue = "00"
        field.alignment = .center
        field.isEditable = true
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = NSColor.white.withAlphaComponent(0.1)
        field.textColor = .labelColor
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        field.wantsLayer = true
        field.layer?.cornerRadius = 8
        field.focusRingType = .none

        field.widthAnchor.constraint(equalToConstant: 40).isActive = true
        field.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = NSNumber(value: maxValue)
        formatter.allowsFloats = false
        field.formatter = formatter

        return field
    }

    private func createUnitLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 24, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func createColonLabel() -> NSTextField {
        let label = NSTextField(labelWithString: ":")
        label.font = NSFont.systemFont(ofSize: 24, weight: .light)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func createButton(title: String, isPrimary: Bool) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.wantsLayer = true

        if isPrimary {
            button.contentTintColor = .white
            button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            button.layer?.cornerRadius = 6
        }

        button.widthAnchor.constraint(equalToConstant: 100).isActive = true

        return button
    }

    private func loadCurrentTime() {
        let elapsed = TimerController.shared.currentElapsed
        let totalSeconds = Int(elapsed)
        hoursValue = totalSeconds / 3600
        minutesValue = (totalSeconds % 3600) / 60
        secondsValue = totalSeconds % 60

        hoursStepper.stringValue = String(format: "%d", hoursValue)
        minutesStepper.stringValue = String(format: "%02d", minutesValue)
        secondsStepper.stringValue = String(format: "%02d", secondsValue)
    }

    func resetToZero() {
        hoursValue = 0
        minutesValue = 0
        secondsValue = 0
        hoursStepper.stringValue = "0"
        minutesStepper.stringValue = "00"
        secondsStepper.stringValue = "00"
    }

    @objc private func cancel() {
        close()
    }

    @objc private func setTime() {
        let hours = Int(hoursStepper.stringValue) ?? 0
        let minutes = min(59, Int(minutesStepper.stringValue) ?? 0)
        let seconds = min(59, Int(secondsStepper.stringValue) ?? 0)

        let totalSeconds = TimeInterval(hours * 3600 + minutes * 60 + seconds)
        TimerController.shared.setTime(totalSeconds)

        close()
    }

    override func cancelOperation(_ sender: Any?) {
        cancel()
    }
}
