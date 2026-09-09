import AppKit

/// Adopted by the shortcut recorder widgets so windows can tell when a key
/// press should be delivered to the recorder instead of being interpreted as a
/// key equivalent (⌘W, Escape, the Quit shortcut).
protocol ShortcutRecording: AnyObject {
    var isRecording: Bool { get }
}

final class ShortcutRecorderView: NSView, ShortcutRecording {
    var shortcut: String = "" {
        didSet {
            updateDisplay()
        }
    }
    var requiresCommand: Bool = false {
        didSet {
            updateDisplay()
        }
    }
    var onShortcutChanged: ((String) -> Void)?
    var isDuplicateShortcut: ((String) -> Bool)?
    var actionName: String = ""

    private(set) var isRecording = false {
        didSet {
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

        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: Design.Size.shortcutFieldMinWidth).isActive = true
        textField.alignment = .center
        textField.isBordered = true
        textField.isEditable = false
        textField.bezelStyle = .roundedBezel

        updateDisplay()
    }

    private func updateDisplay() {
        if isRecording {
            textField.stringValue = "Press key..."
            textField.textColor = .systemBlue
        } else {
            textField.stringValue = formatShortcut(shortcut)
            textField.textColor = .labelColor
        }
    }

    private func formatShortcut(_ key: String) -> String {
        KeyDisplay.string(character: key, requiresCommand: requiresCommand)
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

    /// Losing focus (another recorder started, the window closed) cancels the recording
    /// so two widgets never both show "Press key...".
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

        // Escape cancels rather than becoming the shortcut.
        if event.keyCode == 53 {
            stopRecording()
            return
        }

        let chars = (event.charactersIgnoringModifiers ?? "").lowercased()
        guard !chars.isEmpty else { return }

        if requiresCommand && !event.modifierFlags.contains(.command) {
            return
        }

        if isDuplicateShortcut?(chars) == true {
            stopRecording()
            showDuplicateAlert(for: chars)
            return
        }

        stopRecording()
        shortcut = chars
        onShortcutChanged?(chars)
    }

    private func showDuplicateAlert(for key: String) {
        let alert = NSAlert()
        alert.messageText = "Duplicate Shortcut"
        alert.informativeText = "The shortcut '\(formatShortcut(key))' is already assigned to another action. Please choose a different shortcut."
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
