import AppKit
import ApplicationServices

protocol FullScreenAXMonitorDelegate: AnyObject {
    func fullScreenStateDidChange(isFullScreen: Bool)
}

/// Monitors the frontmost application's focused window for fullscreen state changes
/// using the macOS Accessibility API for low-latency, push-based detection.
final class FullScreenAXMonitor {
    static let shared = FullScreenAXMonitor()
    weak var delegate: FullScreenAXMonitorDelegate?

    // AX observer state
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var appElement: AXUIElement?
    private var windowElement: AXUIElement?

    // Throttle state (leading-edge + trailing-edge)
    private var lastTriggerTime: CFAbsoluteTime = 0
    private let throttleInterval: CFAbsoluteTime = 0.12 // 120ms
    private var pendingCheck: DispatchWorkItem?

    // Cached state
    private(set) var lastKnownState: Bool = false

    private init() {}

    // MARK: - Public API

    func startMonitoring() {
        guard AXIsProcessTrusted() else { return }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        attachToFrontmostApp()
    }

    func stopMonitoring() {
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        teardown()
    }

    /// Manually trigger re-attachment to the frontmost app (call after space changes)
    func reattach() {
        attachToFrontmostApp()
    }

    /// Query current fullscreen state without triggering delegate
    func checkFullScreenState() -> Bool {
        return evaluateFullScreen() ?? false
    }

    // MARK: - App Switching

    @objc private func frontmostAppChanged() {
        attachToFrontmostApp()
        triggerFullScreenCheck()
    }

    private func attachToFrontmostApp() {
        guard AXIsProcessTrusted() else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        let pid = frontApp.processIdentifier

        // Already observing this app
        if pid == observedPID && observer != nil { return }

        teardown()

        observedPID = pid
        appElement = AXUIElementCreateApplication(pid)

        var obs: AXObserver?
        let err = AXObserverCreate(pid, axCallback, &obs)
        guard err == .success, let obs = obs else { return }

        observer = obs
        let src = AXObserverGetRunLoopSource(obs)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)

        // Watch window focus changes at the app level
        if let appEl = appElement {
            AXObserverAddNotification(obs, appEl, kAXFocusedWindowChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
            AXObserverAddNotification(obs, appEl, kAXMainWindowChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        }

        rebindFocusedWindow()
    }

    private func teardown() {
        pendingCheck?.cancel()
        pendingCheck = nil

        if let obs = observer {
            if let appEl = appElement {
                AXObserverRemoveNotification(obs, appEl, kAXFocusedWindowChangedNotification as CFString)
                AXObserverRemoveNotification(obs, appEl, kAXMainWindowChangedNotification as CFString)
            }
            if let winEl = windowElement {
                AXObserverRemoveNotification(obs, winEl, kAXWindowResizedNotification as CFString)
                AXObserverRemoveNotification(obs, winEl, kAXWindowMovedNotification as CFString)
                AXObserverRemoveNotification(obs, winEl, kAXUIElementDestroyedNotification as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        }

        observer = nil
        appElement = nil
        windowElement = nil
        observedPID = 0
    }

    // MARK: - Window Rebinding

    private func rebindFocusedWindow() {
        guard let obs = observer, let appEl = appElement else { return }

        // Remove old window notifications
        if let oldWin = windowElement {
            AXObserverRemoveNotification(obs, oldWin, kAXWindowResizedNotification as CFString)
            AXObserverRemoveNotification(obs, oldWin, kAXWindowMovedNotification as CFString)
            AXObserverRemoveNotification(obs, oldWin, kAXUIElementDestroyedNotification as CFString)
        }

        // Get new focused window
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &value) == .success,
           CFGetTypeID(value) == AXUIElementGetTypeID() {
            let newWin = value as! AXUIElement
            windowElement = newWin

            AXObserverAddNotification(obs, newWin, kAXWindowResizedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
            AXObserverAddNotification(obs, newWin, kAXWindowMovedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
            AXObserverAddNotification(obs, newWin, kAXUIElementDestroyedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        } else {
            windowElement = nil
        }
    }

    // MARK: - AX Event Handling

    fileprivate func handleAXEvent(_ notification: CFString, element: AXUIElement) {
        let notificationName = notification as String

        // Focus changed? Rebind window-level notifications
        if notificationName == kAXFocusedWindowChangedNotification as String ||
           notificationName == kAXMainWindowChangedNotification as String {
            rebindFocusedWindow()
        }

        // Window destroyed? Clear reference
        if notificationName == kAXUIElementDestroyedNotification as String {
            windowElement = nil
        }

        triggerFullScreenCheck()
    }

    // MARK: - Throttle Logic (Leading + Trailing Edge)

    private func triggerFullScreenCheck() {
        let now = CFAbsoluteTimeGetCurrent()

        // Cancel pending trailing-edge check
        pendingCheck?.cancel()

        // Inside throttle window?
        if now - lastTriggerTime < throttleInterval {
            // Schedule trailing-edge check at end of throttle window
            let remainingTime = throttleInterval - (now - lastTriggerTime)
            let workItem = DispatchWorkItem { [weak self] in
                self?.executeFullScreenCheck()
            }
            pendingCheck = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime, execute: workItem)
            return
        }

        // Leading edge - execute immediately
        lastTriggerTime = now
        executeFullScreenCheck()
    }

    private func executeFullScreenCheck() {
        guard let isFullScreen = evaluateFullScreen() else { return }

        if isFullScreen != lastKnownState {
            lastKnownState = isFullScreen
            delegate?.fullScreenStateDidChange(isFullScreen: isFullScreen)
        }
    }

    // MARK: - Fullscreen Detection

    private func evaluateFullScreen() -> Bool? {
        guard let winEl = windowElement else { return nil }

        // Primary: Query AXFullScreen attribute (supported by most apps)
        if let fullScreen = axBool(winEl, "AXFullScreen" as CFString) {
            return fullScreen
        }

        // Fallback: Geometry check (window size ≈ screen size)
        return checkWindowGeometry(winEl)
    }

    private func checkWindowGeometry(_ window: AXUIElement) -> Bool {
        guard let screen = NSScreen.main else { return false }

        guard let size = axCGSize(window, kAXSizeAttribute as CFString),
              let pos = axCGPoint(window, kAXPositionAttribute as CFString) else {
            return false
        }

        let sf = screen.frame
        let tolerance: CGFloat = 10

        let nearFullSize = abs(size.width - sf.width) < tolerance && abs(size.height - sf.height) < tolerance
        let nearOrigin = abs(pos.x - sf.minX) < tolerance && abs(pos.y - sf.minY) < tolerance

        return nearFullSize && nearOrigin
    }

    // MARK: - AX Value Helpers

    private func axBool(_ el: AXUIElement, _ attr: CFString) -> Bool? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(el, attr, &v) == .success else { return nil }
        if let b = v as? Bool { return b }
        if CFGetTypeID(v) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((v as! CFBoolean))
        }
        if let n = v as? NSNumber { return n.boolValue }
        return nil
    }

    private func axCGSize(_ el: AXUIElement, _ attr: CFString) -> CGSize? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(el, attr, &v) == .success else { return nil }
        guard CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var s = CGSize.zero
        return AXValueGetValue((v as! AXValue), .cgSize, &s) ? s : nil
    }

    private func axCGPoint(_ el: AXUIElement, _ attr: CFString) -> CGPoint? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(el, attr, &v) == .success else { return nil }
        guard CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue((v as! AXValue), .cgPoint, &p) ? p : nil
    }
}

// MARK: - AX Observer Callback

private func axCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let monitor = Unmanaged<FullScreenAXMonitor>.fromOpaque(refcon).takeUnretainedValue()
    monitor.handleAXEvent(notification, element: element)
}
