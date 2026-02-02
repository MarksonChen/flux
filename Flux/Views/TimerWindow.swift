import AppKit

final class TimerWindow: NSWindow {
    private let timerView: TimerView
    private var didDrag = false
    private var dragOffset: NSPoint = .zero

    init() {
        timerView = TimerView(frame: .zero)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        restorePosition()
    }

    private func setupWindow() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isMovableByWindowBackground = false

        timerView.translatesAutoresizingMaskIntoConstraints = false

        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.addSubview(timerView)

        contentView = containerView

        NSLayoutConstraint.activate([
            timerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            timerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            timerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            timerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    private func restorePosition() {
        if let savedPosition = Persistence.shared.windowPosition {
            setFrameOrigin(savedPosition)

            if let displayID = Persistence.shared.windowDisplayID {
                let screens = NSScreen.screens
                if let targetScreen = screens.first(where: { screen in
                    let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                    return screenNumber == displayID
                }) {
                    var newOrigin = savedPosition
                    let screenFrame = targetScreen.frame
                    newOrigin.x = max(screenFrame.minX, min(newOrigin.x, screenFrame.maxX - frame.width))
                    newOrigin.y = max(screenFrame.minY, min(newOrigin.y, screenFrame.maxY - frame.height))
                    setFrameOrigin(newOrigin)
                }
            }
        } else {
            center()
        }
    }

    private func savePosition() {
        Persistence.shared.windowPosition = frame.origin

        if let screen = screen {
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                Persistence.shared.windowDisplayID = screenNumber
            }
        }
    }

    func refreshAppearance() {
        timerView.applySettings()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        dragOffset = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        didDrag = true
        let screenLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: screenLocation.x - dragOffset.x,
            y: screenLocation.y - dragOffset.y
        )
        setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            savePosition()
        } else if event.clickCount == 2 {
            ShortcutManager.shared.handleLeftDoubleClick()
        } else {
            ShortcutManager.shared.handleLeftClick()
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            ShortcutManager.shared.handleRightDoubleClick()
        } else {
            ShortcutManager.shared.handleRightClick()
        }
    }

    override func keyDown(with event: NSEvent) {
        if !ShortcutManager.shared.handleKeyDown(event) {
            super.keyDown(with: event)
        }
    }

    override func accessibilityValue() -> Any? {
        return TimerController.shared.displayTime
    }
}
