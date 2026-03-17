import AppKit
import Combine

final class TimerView: NSView {
    private let textField: NSTextField
    private var cancellables = Set<AnyCancellable>()
    private let timerController = TimerController.shared

    override init(frame frameRect: NSRect) {
        textField = NSTextField(labelWithString: "00:00")
        super.init(frame: frameRect)
        setupView()
        bindToController()
    }

    required init?(coder: NSCoder) {
        textField = NSTextField(labelWithString: "00:00")
        super.init(coder: coder)
        setupView()
        bindToController()
    }

    private func setupView() {
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        applySettings()
    }

    private func bindToController() {
        timerController.$displayTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.textField.stringValue = time
                self?.updateSize()
            }
            .store(in: &cancellables)
    }

    func applySettings() {
        let settings = Persistence.shared.appSettings

        var font: NSFont?
        if settings.fontFamily == "SF Pro" {
            font = NSFont.systemFont(ofSize: settings.fontSize, weight: .regular)
        } else {
            font = NSFont(name: settings.fontFamily, size: settings.fontSize)
        }
        textField.font = font ?? NSFont.systemFont(ofSize: settings.fontSize)
        textField.textColor = settings.textColor.withAlphaComponent(settings.opacity)

        textField.backgroundColor = .clear
        textField.isBordered = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.drawsBackground = false

        updateSize()
    }

    private func updateSize() {
        textField.sizeToFit()
        let textSize = textField.frame.size
        let padding: CGFloat = 20
        let newSize = NSSize(width: textSize.width + padding, height: textSize.height + padding)

        if let window = window {
            var frame = window.frame
            if frame.size != newSize {
                // Adjust origin.y so the TOP of the window stays fixed
                // (AppKit origin is at bottom-left, so we compensate for height change)
                frame.origin.y += frame.size.height - newSize.height
                frame.size = newSize
                window.setFrame(frame, display: true)
            }
        }

        setFrameSize(newSize)
    }

    override var intrinsicContentSize: NSSize {
        let textSize = textField.intrinsicContentSize
        let padding: CGFloat = 20
        return NSSize(width: textSize.width + padding, height: textSize.height + padding)
    }
}
