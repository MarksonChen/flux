import AppKit

final class ShortcutRecorderView: NSView {
    var shortcut: String = "" {
        didSet {
            updateDisplay()
        }
    }
    var requiresCommand: Bool = false
    var onShortcutChanged: ((String) -> Void)?

    private var isRecording = false
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
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
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
        if key == " " {
            return requiresCommand ? "⌘Space" : "Space"
        }
        if requiresCommand {
            return "⌘\(key.uppercased())"
        }
        return key.uppercased()
    }

    @objc private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            recordButton.title = "Cancel"
            window?.makeFirstResponder(self)
        } else {
            recordButton.title = "Record"
        }
        updateDisplay()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let chars = event.charactersIgnoringModifiers ?? ""
        guard !chars.isEmpty else { return }

        if requiresCommand && !event.modifierFlags.contains(.command) {
            return
        }

        shortcut = chars.lowercased()
        isRecording = false
        recordButton.title = "Record"
        updateDisplay()
        onShortcutChanged?(shortcut)
    }

    override func cancelOperation(_ sender: Any?) {
        if isRecording {
            isRecording = false
            recordButton.title = "Record"
            updateDisplay()
        }
    }
}
