import AppKit

final class GlobalShortcutRecorderView: NSView {
    var keyCode: UInt16 = 0 {
        didSet { updateDisplay() }
    }
    var modifiers: NSEvent.ModifierFlags = [] {
        didSet { updateDisplay() }
    }
    var onShortcutChanged: ((UInt16, NSEvent.ModifierFlags) -> Void)?

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
            textField.stringValue = formatShortcut()
            textField.textColor = .labelColor
        }
    }

    private func formatShortcut() -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        let keyString = keyCodeToString(keyCode)
        parts.append(keyString)
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyCodeMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`", 49: "Space"
        ]
        return keyCodeMap[keyCode] ?? "?"
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

        // Require at least one modifier key
        let modifierMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let pressedModifiers = event.modifierFlags.intersection(modifierMask)

        guard !pressedModifiers.isEmpty else { return }

        keyCode = event.keyCode
        modifiers = pressedModifiers
        isRecording = false
        recordButton.title = "Record"
        updateDisplay()
        onShortcutChanged?(keyCode, modifiers)
    }

    override func cancelOperation(_ sender: Any?) {
        if isRecording {
            isRecording = false
            recordButton.title = "Record"
            updateDisplay()
        }
    }
}
