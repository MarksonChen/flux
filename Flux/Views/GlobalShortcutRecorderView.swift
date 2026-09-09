import AppKit

final class GlobalShortcutRecorderView: NSView, ShortcutRecording {
    var keyCode: UInt16 = 0 {
        didSet { updateDisplay() }
    }
    var modifiers: NSEvent.ModifierFlags = [] {
        didSet { updateDisplay() }
    }
    var onShortcutChanged: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var isDuplicateShortcut: ((UInt16, NSEvent.ModifierFlags) -> Bool)?

    private(set) var isRecording = false {
        didSet {
            guard isRecording != oldValue else { return }
            // The live event tap would otherwise swallow (and act on) the very
            // combination being recorded, making it impossible to re-record it.
            if isRecording {
                ShortcutManager.shared.beginSuspendingGlobalShortcuts()
            } else {
                ShortcutManager.shared.endSuspendingGlobalShortcuts()
            }
            recordButton.title = isRecording ? "Cancel" : "Record"
            updateDisplay()
        }
    }

    private let textField: NSTextField
    private let recordButton: NSButton

    override init(frame frameRect: NSRect) {
        textField = NSTextField(labelWithString: "")
        recordButton = NSButton(title: "Record", target: nil, action: nil)

        super.init(frame: frameRect)

        recordButton.target = self
        recordButton.action = #selector(toggleRecording)

        setupView()
    }

    required init?(coder: NSCoder) {
        textField = NSTextField(labelWithString: "")
        recordButton = NSButton(title: "Record", target: nil, action: nil)

        super.init(coder: coder)

        recordButton.target = self
        recordButton.action = #selector(toggleRecording)

        setupView()
    }

    deinit {
        if isRecording {
            ShortcutManager.shared.endSuspendingGlobalShortcuts()
        }
    }

    private func setupView() {
        let stack = NSStackView(views: [textField, recordButton])
        stack.orientation = .horizontal
        stack.spacing = Design.Spacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        textField.alignment = .center
        textField.isBordered = true
        textField.isEditable = false
        textField.bezelStyle = .roundedBezel

        updateDisplay()
    }

    private func updateDisplay() {
        if isRecording {
            textField.stringValue = "Press shortcut..."
            textField.textColor = .systemBlue
        } else {
            textField.stringValue = KeyDisplay.string(keyCode: keyCode, modifiers: modifiers)
            textField.textColor = .labelColor
        }
    }

    // MARK: - Recording

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        isRecording = false
    }

    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording()
        }
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let pressedModifiers = event.modifierFlags.intersection(GlobalShortcutBindings.relevantModifiers)

        // Bare Escape cancels rather than becoming the shortcut.
        if event.keyCode == 53 && pressedModifiers.isEmpty {
            stopRecording()
            return
        }

        // Require Control, Option or Command. A Shift-only combination such as ⇧T
        // would hijack ordinary typing of capital letters in every app.
        guard !pressedModifiers.isDisjoint(with: [.control, .option, .command]) else {
            NSSound.beep()
            return
        }

        if isDuplicateShortcut?(event.keyCode, pressedModifiers) == true {
            stopRecording()
            showDuplicateAlert(keyCode: event.keyCode, modifiers: pressedModifiers)
            return
        }

        stopRecording()
        keyCode = event.keyCode
        modifiers = pressedModifiers
        onShortcutChanged?(keyCode, modifiers)
    }

    private func showDuplicateAlert(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        let alert = NSAlert()
        alert.messageText = "Duplicate Shortcut"
        alert.informativeText = "The shortcut '\(KeyDisplay.string(keyCode: keyCode, modifiers: modifiers))' is already assigned to the other global shortcut. Please choose a different shortcut."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    override func cancelOperation(_ sender: Any?) {
        if isRecording {
            stopRecording()
        }
    }
}
