import AppKit
import Combine

final class TimerView: NSView {
    private static let padding: CGFloat = 20

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

        textField.font = Self.resolveFont(family: settings.fontFamily, size: settings.fontSize)
        textField.textColor = settings.textColor.withAlphaComponent(settings.opacity)

        textField.backgroundColor = .clear
        textField.isBordered = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.drawsBackground = false

        updateSize()
    }

    /// The font popup lists font *families*, but `NSFont(name:)` looks up a face
    /// name. Families whose regular face is named differently (e.g. "Avenir Next"
    /// → "AvenirNext-Regular") would otherwise silently fall back to the system
    /// font, so resolve by family through the font manager as well.
    private static func resolveFont(family: String, size: CGFloat) -> NSFont {
        if family == "SF Pro" {
            return NSFont.systemFont(ofSize: size, weight: .regular)
        }
        if let byName = NSFont(name: family, size: size) {
            return byName
        }
        if let byFamily = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            return byFamily
        }
        return NSFont.systemFont(ofSize: size)
    }

    private func updateSize() {
        textField.sizeToFit()
        let textSize = textField.frame.size
        let newSize = NSSize(width: textSize.width + Self.padding, height: textSize.height + Self.padding)

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
        return NSSize(width: textSize.width + Self.padding, height: textSize.height + Self.padding)
    }
}
