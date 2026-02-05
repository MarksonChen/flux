import AppKit
import CoreGraphics

final class TimerWindow: NSWindow, FullScreenAXMonitorDelegate {
    private let timerView: TimerView
    private var didDrag = false
    private var dragOffset: NSPoint = .zero

    // Full-screen hiding
    private var pendingUpdate: DispatchWorkItem?
    private var pollTimer: DispatchSourceTimer?
    private var axMonitorActive = false

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
        setupFullScreenObservers()
        setupAXMonitor()
    }

    deinit {
        pendingUpdate?.cancel()
        pollTimer?.cancel()
        FullScreenAXMonitor.shared.stopMonitoring()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    private func setupWindow() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        updateCollectionBehavior()
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
        updateCollectionBehavior()
    }

    // MARK: - Collection Behavior & Spaces Management

    private func desiredCollectionBehavior() -> NSWindow.CollectionBehavior {
        let settings = Persistence.shared.appSettings

        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary]

        // Only allow participation in fullscreen if the user explicitly wants it
        if settings.showInFullScreen {
            behavior.insert(.fullScreenAuxiliary)
        }

        // Defensive: some paths / OS versions can implicitly introduce this
        behavior.remove(.moveToActiveSpace)

        return behavior
    }

    private func applyDesiredCollectionBehavior() {
        collectionBehavior = desiredCollectionBehavior()
    }

    /// Centralized show method that reasserts collectionBehavior to preserve Spaces membership
    private func showTimerWindow() {
        // IMPORTANT: membership is (re)computed when ordering in
        applyDesiredCollectionBehavior()

        if !isVisible {
            alphaValue = 1.0
            // Prefer orderFront over orderFrontRegardless; use window level for "always on top"
            orderFront(nil)
        }

        // Sequoia quirk: ordering-in can override behavior; reassert next runloop
        DispatchQueue.main.async { [weak self] in
            self?.applyDesiredCollectionBehavior()
        }
    }

    /// Centralized hide method that reasserts collectionBehavior after hide
    private func hideTimerWindow() {
        if isVisible {
            orderOut(nil)
        }

        // Reasserting after orderOut prevents "sticky space" edge cases
        DispatchQueue.main.async { [weak self] in
            self?.applyDesiredCollectionBehavior()
        }
    }

    private func updateCollectionBehavior() {
        let settings = Persistence.shared.appSettings
        applyDesiredCollectionBehavior()

        if settings.showInFullScreen {
            stopPolling()
            showTimerWindow()
        } else {
            scheduleFullScreenCheck()
        }
    }

    // MARK: - Full-Screen Detection (CGWindowList approach)

    private func setupFullScreenObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(scheduleFullScreenCheck),
                              name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(scheduleFullScreenCheck),
                              name: NSWorkspace.didActivateApplicationNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(scheduleFullScreenCheck),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Observe any window entering full screen (fires early in transition)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFullScreenTransition),
                                               name: NSWindow.willEnterFullScreenNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleFullScreenCheck),
                                               name: NSWindow.didExitFullScreenNotification, object: nil)

        scheduleFullScreenCheck()
    }

    private func setupAXMonitor() {
        let monitor = FullScreenAXMonitor.shared
        monitor.delegate = self
        monitor.startMonitoring()
        axMonitorActive = AXIsProcessTrusted()
    }

    // MARK: - FullScreenAXMonitorDelegate

    func fullScreenStateDidChange(isFullScreen: Bool) {
        let settings = Persistence.shared.appSettings
        guard !settings.showInFullScreen else { return }

        if isFullScreen {
            hideTimerWindow()
            startFallbackPolling()
        } else {
            // Verify with Dock heuristic before showing (avoid false positive)
            if !systemIsShowingFullScreenSpace() {
                stopPolling()
                showTimerWindow()
            }
        }
    }

    @objc private func handleFullScreenTransition() {
        // Hide immediately when any window starts entering full screen
        let settings = Persistence.shared.appSettings
        if !settings.showInFullScreen && isVisible {
            hideTimerWindow()
            startFallbackPolling()
        }
    }

    @objc private func scheduleFullScreenCheck() {
        pendingUpdate?.cancel()

        // Trigger AX monitor reattachment (handles space switches, app changes)
        FullScreenAXMonitor.shared.reattach()

        // No delay - check immediately using Dock heuristic as fallback/validator
        updateFullScreenVisibility()
    }

    private func updateFullScreenVisibility() {
        let settings = Persistence.shared.appSettings
        if settings.showInFullScreen {
            stopPolling()
            showTimerWindow()
            return
        }

        let shouldHide = systemIsShowingFullScreenSpace()

        if shouldHide {
            hideTimerWindow()
            startFallbackPolling()
        } else {
            stopPolling()
            showTimerWindow()
        }
    }

    /// Detect full-screen space via CGWindowList - counts Dock windows with negative layer
    /// Works on macOS 15 Sequoia and earlier versions
    private func systemIsShowingFullScreenSpace() -> Bool {
        // IMPORTANT: Do NOT use .excludeDesktopElements - it excludes Dock windows!
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return false }

        var negativeDockLayerCount = 0

        for window in windows {
            guard (window[kCGWindowOwnerName as String] as? String) == "Dock" else { continue }

            // Only count windows that are actually onscreen
            let onscreen = (window[kCGWindowIsOnscreen as String] as? Int) ?? 0
            guard onscreen == 1 else { continue }

            // Sequoia 15+ heuristic: count Dock windows with negative layer
            if let layer = window[kCGWindowLayer as String] as? Int64, layer < 0 {
                negativeDockLayerCount += 1
                if negativeDockLayerCount >= 2 {
                    return true
                }
            }

            // Fallback for older macOS versions
            if (window[kCGWindowName as String] as? String) == "Fullscreen Backdrop" {
                return true
            }
        }

        return false
    }

    /// Debug helper - call this to log Dock windows to console
    func logDockWindows() {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            print("CGWindowListCopyWindowInfo returned nil")
            return
        }

        let dock = info.filter { ($0[kCGWindowOwnerName as String] as? String) == "Dock" }

        print("=== Dock windows: \(dock.count) ===")
        for w in dock {
            let name = w[kCGWindowName as String] as? String ?? ""
            let layer = (w[kCGWindowLayer as String] as? Int64) ?? 0
            let onscreen = (w[kCGWindowIsOnscreen as String] as? Int) ?? -1
            let alpha = (w[kCGWindowAlpha as String] as? Double) ?? -1
            let bounds = w[kCGWindowBounds as String] ?? "?"
            print("  layer=\(layer) onscreen=\(onscreen) alpha=\(alpha) name='\(name)' bounds=\(bounds)")
        }
        print("=== systemIsShowingFullScreenSpace() = \(systemIsShowingFullScreenSpace()) ===")
    }

    private func startFallbackPolling() {
        guard pollTimer == nil else { return }

        // Tiered polling: 1 Hz when AX monitor is active (it handles most events),
        // 4 Hz fallback when AX is unavailable
        let interval: TimeInterval = axMonitorActive ? 1.0 : 0.25

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            // Check both AX state and Dock heuristic
            let axFullScreen = FullScreenAXMonitor.shared.checkFullScreenState()
            let dockFullScreen = self.systemIsShowingFullScreenSpace()

            if !axFullScreen && !dockFullScreen {
                self.stopPolling()
                self.showTimerWindow()
            }
        }
        pollTimer = timer
        timer.resume()
    }

    private func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
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

    override func rightMouseDown(with event: NSEvent) {
        // Capture right mouse down to prevent any default window behavior
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
