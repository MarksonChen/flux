import AppKit

final class SetTimeWindowController: NSWindowController {
    private var hoursStepper: NSTextField!
    private var minutesStepper: NSTextField!
    private var secondsStepper: NSTextField!

    private var hoursValue: Int = 0
    private var minutesValue: Int = 0
    private var secondsValue: Int = 0

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.titled, .closable],
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
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20)
        ])

        let timeRow = NSStackView()
        timeRow.orientation = .horizontal
        timeRow.spacing = 10

        hoursStepper = createSpinnerField(maxValue: 999)
        minutesStepper = createSpinnerField(maxValue: 59)
        secondsStepper = createSpinnerField(maxValue: 59)

        let hoursLabel = NSTextField(labelWithString: "H")
        let minutesLabel = NSTextField(labelWithString: "M")
        let secondsLabel = NSTextField(labelWithString: "S")

        timeRow.addArrangedSubview(hoursStepper)
        timeRow.addArrangedSubview(hoursLabel)
        timeRow.addArrangedSubview(minutesStepper)
        timeRow.addArrangedSubview(minutesLabel)
        timeRow.addArrangedSubview(secondsStepper)
        timeRow.addArrangedSubview(secondsLabel)

        stackView.addArrangedSubview(timeRow)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let setButton = NSButton(title: "Set Time", target: self, action: #selector(setTime))
        setButton.keyEquivalent = "\r"

        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(setButton)

        stackView.addArrangedSubview(buttonRow)
    }

    private func createSpinnerField(maxValue: Int) -> NSTextField {
        let field = NSTextField()
        field.stringValue = "00"
        field.alignment = .center
        field.isEditable = true
        field.isBordered = true
        field.bezelStyle = .roundedBezel

        field.widthAnchor.constraint(equalToConstant: 50).isActive = true

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = NSNumber(value: maxValue)
        formatter.allowsFloats = false
        field.formatter = formatter

        return field
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
