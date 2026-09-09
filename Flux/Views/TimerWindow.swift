import AppKit
import CoreGraphics

final class TimerWindow: NSWindow, FullScreenAXMonitorDelegate {
    private let timerView: TimerView

    // Button state. A click is a down *and* an up on this window. Tools that
    // intercept mouse chords (e.g. BetterTouchTool's left+right click trigger)
    // swallow the button-down but let the button-up through, and macOS then
    // hands that orphan up to the last window that saw a down for that button,
    // which can be this one even when the cursor is far away. Without these
    // flags such an orphan right-mouse-up counted as a right-click and reset
    // the timer.
    private var leftButtonDownInWindow = false
    private var rightButtonDownInWindow = false

    // Dragging
    private var isDragging = false
    private var mouseDownLocation: NSPoint = .zero
    /// Movement below this distance is treated as a click, not a drag, so a
    /// slightly shaky click still triggers its action.
    private static let dragThreshold: CGFloat = 3
    /// How much of the window must stay on a screen while dragging, so the
    /// borderless window can never be pushed fully off-screen and lost.
    private static let minimumVisibleEdge: CGFloat = 24

    // Click disambiguation
    private var pendingSingleClick: DispatchWorkItem?

    // Full-screen hiding
    private var pollTimer: DispatchSourceTimer?
    private var axMonitorActive = false

    // Soft-hide state (avoids orderOut/orderFront cycle that breaks space membership)
    private var softHiddenForFullScreen = false

    init() {
        timerView = TimerView(frame: .zero)

        super.init(
            contentRect: NSRect(origin: .zero, size: Design.WindowSize.timer),
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
        pendingSingleClick?.cancel()
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

        // Size the window to its text now that the view is attached. Otherwise the
        // saved origin is applied to the placeholder frame and the later resize
        // (which keeps the top edge fixed) shifts the window down on every launch.
        timerView.applySettings()
    }

    // MARK: - Position persistence

    private func restorePosition() {
        guard let savedPosition = Persistence.shared.windowPosition else {
            center()
            return
        }

        // Prefer the display the window was last on. If that display is gone,
        // fall back to whichever screen the saved point lands on, and finally to
        // the main screen, so a position saved on a disconnected monitor never
        // restores off-screen.
        let savedRect = NSRect(origin: savedPosition, size: frame.size)
        let screen = Self.screen(withDisplayID: Persistence.shared.windowDisplayID)
            ?? NSScreen.screens.first { $0.frame.intersects(savedRect) }
            ?? NSScreen.main

        guard let screen else {
            setFrameOrigin(savedPosition)
            return
        }

        setFrameOrigin(Self.clamp(origin: savedPosition, size: frame.size, into: screen.frame))
    }

    private func savePosition() {
        Persistence.shared.windowPosition = frame.origin
        Persistence.shared.windowDisplayID = screen?.displayID
    }

    private static func screen(withDisplayID id: CGDirectDisplayID?) -> NSScreen? {
        guard let id else { return nil }
        return NSScreen.screens.first { $0.displayID == id }
    }

    /// Origin that keeps a window of `size` entirely inside `bounds`.
    private static func clamp(origin: NSPoint, size: NSSize, into bounds: NSRect) -> NSPoint {
        NSPoint(
            x: max(bounds.minX, min(origin.x, bounds.maxX - size.width)),
            y: max(bounds.minY, min(origin.y, bounds.maxY - size.height))
        )
    }

    func refreshAppearance() {
        timerView.applySettings()
        updateCollectionBehavior()
    }

    // MARK: - Collection Behavior & Spaces Management

    private func desiredCollectionBehavior() -> NSWindow.CollectionBehavior {
        let settings = Persistence.shared.appSettings

        var behavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .transient,       // Keeps overlay out of Mission Control
            .ignoresCycle     // Keeps overlay out of Cmd+Tab cycling
        ]

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

    /// Soft-hide for fullscreen: keeps window ordered-in but invisible.
    /// This avoids the WindowServer space-assignment quirk where orderOut/orderFront
    /// during a fullscreen transition causes the window to be pinned to a single space.
    private func softHideForFullScreen() {
        guard !softHiddenForFullScreen else { return }
        softHiddenForFullScreen = true

        // Keep the window ordered-in (no orderOut!) to preserve space membership
        alphaValue = 0.0
        ignoresMouseEvents = true
    }

    /// Restore visibility after fullscreen without triggering space reassignment.
    private func softShowAfterFullScreen() {
        guard softHiddenForFullScreen else { return }
        softHiddenForFullScreen = false

        // Reassert behavior but don't orderFront - window is already ordered in
        applyDesiredCollectionBehavior()

        ignoresMouseEvents = false
        alphaValue = 1.0

        // Only order in if something else legitimately made it not visible
        if !isVisible {
            orderFront(nil)
            DispatchQueue.main.async { [weak self] in
                self?.applyDesiredCollectionBehavior()
            }
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

        // Accessibility may be granted after launch; start the AX monitor then.
        NotificationCenter.default.addObserver(self, selector: #selector(accessibilityPermissionGranted),
                                               name: ShortcutManager.accessibilityPermissionGranted, object: nil)

        scheduleFullScreenCheck()
    }

    private func setupAXMonitor() {
        let monitor = FullScreenAXMonitor.shared
        monitor.delegate = self
        monitor.startMonitoring()
        axMonitorActive = AXIsProcessTrusted()
    }

    @objc private func accessibilityPermissionGranted() {
        setupAXMonitor()
        scheduleFullScreenCheck()
    }

    // MARK: - FullScreenAXMonitorDelegate

    func fullScreenStateDidChange(isFullScreen: Bool) {
        let settings = Persistence.shared.appSettings
        guard !settings.showInFullScreen else { return }

        if isFullScreen {
            softHideForFullScreen()
            startFallbackPolling()
        } else {
            // Verify with Dock heuristic before showing (avoid false positive)
            if !systemIsShowingFullScreenSpace() {
                stopPolling()
                softShowAfterFullScreen()
            }
        }
    }

    @objc private func handleFullScreenTransition() {
        // Hide immediately when any window starts entering full screen
        let settings = Persistence.shared.appSettings
        if !settings.showInFullScreen && (isVisible || softHiddenForFullScreen == false) {
            softHideForFullScreen()
            startFallbackPolling()
        }
    }

    @objc private func scheduleFullScreenCheck() {
        // Trigger AX monitor reattachment (handles space switches, app changes)
        FullScreenAXMonitor.shared.reattach()

        // No delay - check immediately using Dock heuristic as fallback/validator
        updateFullScreenVisibility()
    }

    private func updateFullScreenVisibility() {
        let settings = Persistence.shared.appSettings
        if settings.showInFullScreen {
            stopPolling()
            // If we were soft-hidden, restore; otherwise use normal show
            if softHiddenForFullScreen {
                softShowAfterFullScreen()
            } else {
                showTimerWindow()
            }
            return
        }

        let shouldHide = systemIsShowingFullScreenSpace()

        if shouldHide {
            softHideForFullScreen()
            startFallbackPolling()
        } else {
            stopPolling()
            softShowAfterFullScreen()
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
                self.softShowAfterFullScreen()
            }
        }
        pollTimer = timer
        timer.resume()
    }

    private func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    // MARK: - Mouse handling

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        leftButtonDownInWindow = true
        isDragging = false
        mouseDownLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard leftButtonDownInWindow else { return }
        if !isDragging {
            let dx = event.locationInWindow.x - mouseDownLocation.x
            let dy = event.locationInWindow.y - mouseDownLocation.y
            guard hypot(dx, dy) >= Self.dragThreshold else { return }
            isDragging = true
            cancelPendingSingleClick()
        }

        let mouseLocation = NSEvent.mouseLocation
        let proposedOrigin = NSPoint(
            x: mouseLocation.x - mouseDownLocation.x,
            y: mouseLocation.y - mouseDownLocation.y
        )
        setFrameOrigin(constrainedForDragging(proposedOrigin, mouseLocation: mouseLocation))
    }

    /// Keeps at least `minimumVisibleEdge` points of the window on the screen
    /// under the cursor, which still lets the window cross between displays.
    private func constrainedForDragging(_ origin: NSPoint, mouseLocation: NSPoint) -> NSPoint {
        let screenUnderMouse = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
        guard let bounds = (screenUnderMouse ?? screen ?? NSScreen.main)?.frame else { return origin }

        let edge = Self.minimumVisibleEdge
        let size = frame.size
        return NSPoint(
            x: max(bounds.minX - size.width + edge, min(origin.x, bounds.maxX - edge)),
            y: max(bounds.minY - size.height + edge, min(origin.y, bounds.maxY - edge))
        )
    }

    override func mouseUp(with event: NSEvent) {
        guard leftButtonDownInWindow else { return }  // orphan up, not a click
        leftButtonDownInWindow = false

        if isDragging {
            isDragging = false
            savePosition()
            return
        }

        let bindings = Persistence.shared.shortcutBindings
        dispatchClick(
            event,
            singleAction: bindings.leftClickAction,
            doubleAction: bindings.leftDoubleClickAction,
            single: ShortcutManager.shared.handleLeftClick,
            double: ShortcutManager.shared.handleLeftDoubleClick
        )
    }

    override func rightMouseDown(with event: NSEvent) {
        // Swallow the default behavior; just remember that the press started here.
        rightButtonDownInWindow = true
    }

    override func rightMouseUp(with event: NSEvent) {
        guard rightButtonDownInWindow else { return }  // orphan up, not a click
        rightButtonDownInWindow = false

        let bindings = Persistence.shared.shortcutBindings
        dispatchClick(
            event,
            singleAction: bindings.rightClickAction,
            doubleAction: bindings.rightDoubleClickAction,
            single: ShortcutManager.shared.handleRightClick,
            double: ShortcutManager.shared.handleRightDoubleClick
        )
    }

    /// Routes a click to its single or double-click handler.
    ///
    /// The first click of a double-click arrives with `clickCount == 1`, so when a
    /// double-click action is configured the single-click action is deferred by
    /// the system double-click interval and cancelled if a second click arrives.
    /// Otherwise a double-click would fire both actions.
    private func dispatchClick(
        _ event: NSEvent,
        singleAction: ShortcutBindings.MouseAction,
        doubleAction: ShortcutBindings.MouseAction,
        single: @escaping () -> Void,
        double: @escaping () -> Void
    ) {
        switch event.clickCount {
        case 1:
            guard singleAction != .none else { return }
            guard doubleAction != .none else {
                single()
                return
            }
            cancelPendingSingleClick()
            let workItem = DispatchWorkItem { [weak self] in
                self?.pendingSingleClick = nil
                single()
            }
            pendingSingleClick = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: workItem)
        case 2:
            cancelPendingSingleClick()
            double()
        default:
            cancelPendingSingleClick()
        }
    }

    private func cancelPendingSingleClick() {
        pendingSingleClick?.cancel()
        pendingSingleClick = nil
    }

    // MARK: - Keyboard & accessibility

    override func keyDown(with event: NSEvent) {
        if !ShortcutManager.shared.handleKeyDown(event) {
            super.keyDown(with: event)
        }
    }

    override func accessibilityValue() -> Any? {
        return TimerController.shared.displayTime
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
