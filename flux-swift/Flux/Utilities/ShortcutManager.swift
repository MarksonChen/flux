import AppKit
import ApplicationServices

protocol ShortcutManagerDelegate: AnyObject {
    func togglePauseResume()
    func copyTime()
    func openSetTime()
    func openHistory()
    func openSettings()
    func resetTimer()
    func copyAndReset()
    func quit()
}

final class ShortcutManager {
    static let shared = ShortcutManager()
    weak var delegate: ShortcutManagerDelegate?

    /// Posted on the main thread when Accessibility permission is granted after
    /// launch, so components that need it (the fullscreen monitor) can start.
    static let accessibilityPermissionGranted = Notification.Name("ShortcutManager.accessibilityPermissionGranted")

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var accessibilityPollTimer: Timer?

    /// Nesting count of active suspensions. While positive, global shortcuts pass
    /// through untouched so the key combination being recorded in Settings is not
    /// swallowed and acted on by the event tap.
    private var suspensionCount = 0

    private init() {}

    // MARK: - Global shortcuts (event tap)

    func startGlobalMonitoring() {
        stopGlobalMonitoring()

        // First check if already trusted (without prompting)
        if AXIsProcessTrusted() {
            registerEventTap()
            return
        }

        // Not trusted yet - prompt the user
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )

        // Poll until permission is granted
        startAccessibilityPolling()
    }

    func stopGlobalMonitoring() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    func beginSuspendingGlobalShortcuts() {
        suspensionCount += 1
    }

    func endSuspendingGlobalShortcuts() {
        suspensionCount = max(0, suspensionCount - 1)
    }

    private func registerEventTap() {
        guard eventTap == nil else { return }

        // Create event tap for keyDown events
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, _ in
                ShortcutManager.shared.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            print("Failed to create event tap")
            return
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables a tap that is too slow or on certain user input; re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown, suspensionCount == 0 else {
            return Unmanaged.passUnretained(event)
        }

        let bindings = Persistence.shared.globalShortcutBindings
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let flags = Self.modifierFlags(from: event.flags)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        let action: (() -> Void)?
        if bindings.copyAndResetEnabled,
           keyCode == bindings.copyAndResetKeyCode,
           flags == bindings.copyAndResetModifierFlags {
            action = { [weak self] in self?.delegate?.copyAndReset() }
        } else if bindings.toggleEnabled,
                  keyCode == bindings.toggleKeyCode,
                  flags == bindings.toggleModifierFlags {
            action = { [weak self] in self?.delegate?.togglePauseResume() }
        } else {
            action = nil
        }

        guard let action else {
            // Pass through unmatched events
            return Unmanaged.passUnretained(event)
        }

        // Holding the shortcut down must not fire repeatedly, but the repeats are
        // still consumed so they do not leak into the frontmost app.
        if !isRepeat {
            DispatchQueue.main.async(execute: action)
        }
        return nil
    }

    private static func modifierFlags(from cgFlags: CGEventFlags) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if cgFlags.contains(.maskControl) { flags.insert(.control) }
        if cgFlags.contains(.maskAlternate) { flags.insert(.option) }
        if cgFlags.contains(.maskShift) { flags.insert(.shift) }
        if cgFlags.contains(.maskCommand) { flags.insert(.command) }
        return flags
    }

    // MARK: - Accessibility permission

    private func startAccessibilityPolling() {
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, AXIsProcessTrusted() else { return }
            self.accessibilityPollTimer?.invalidate()
            self.accessibilityPollTimer = nil
            self.registerEventTap()
            NotificationCenter.default.post(name: ShortcutManager.accessibilityPermissionGranted, object: self)
            self.showAccessibilityGrantedAlert()
        }
    }

    private func showAccessibilityGrantedAlert() {
        let alert = NSAlert()
        alert.messageText = "Global Shortcuts Enabled"
        alert.informativeText = "Accessibility permission granted. Global shortcuts are now active."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Local shortcuts (timer window)

    /// Handles a key press in the timer window. Returns true when the event
    /// matched a binding, whether or not an action ran (key repeats are consumed
    /// without re-triggering).
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let action = localAction(for: event) else { return false }
        if !event.isARepeat {
            action()
        }
        return true
    }

    /// True when the event matches the configured Quit shortcut. Lets dialog
    /// windows honor the same binding as the timer window.
    func handleQuitKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              Self.characters(of: event) == Persistence.shared.shortcutBindings.quit else {
            return false
        }
        delegate?.quit()
        return true
    }

    private func localAction(for event: NSEvent) -> (() -> Void)? {
        let bindings = Persistence.shared.shortcutBindings
        let chars = Self.characters(of: event)
        guard !chars.isEmpty else { return nil }

        let modifiers = event.modifierFlags.intersection(GlobalShortcutBindings.relevantModifiers)

        if modifiers.contains(.command) {
            switch chars {
            case bindings.copyTime:
                return { [weak self] in self?.delegate?.copyTime() }
            case bindings.openSetTime:
                return { [weak self] in self?.delegate?.openSetTime() }
            case bindings.openHistory:
                return { [weak self] in self?.delegate?.openHistory() }
            case bindings.openSettings:
                return { [weak self] in self?.delegate?.openSettings() }
            case bindings.quit:
                return { [weak self] in self?.delegate?.quit() }
            default:
                return nil
            }
        }

        // The toggle shortcut is a bare key. Ignore it when Control or Option are
        // held so it does not shadow unrelated combinations.
        if modifiers.isDisjoint(with: [.control, .option]), chars == bindings.togglePauseResume {
            return { [weak self] in self?.delegate?.togglePauseResume() }
        }

        return nil
    }

    private static func characters(of event: NSEvent) -> String {
        (event.charactersIgnoringModifiers ?? "").lowercased()
    }

    // MARK: - Mouse actions

    func handleLeftClick() {
        performMouseAction(Persistence.shared.shortcutBindings.leftClickAction)
    }

    func handleRightClick() {
        performMouseAction(Persistence.shared.shortcutBindings.rightClickAction)
    }

    func handleLeftDoubleClick() {
        performMouseAction(Persistence.shared.shortcutBindings.leftDoubleClickAction)
    }

    func handleRightDoubleClick() {
        performMouseAction(Persistence.shared.shortcutBindings.rightDoubleClickAction)
    }

    private func performMouseAction(_ action: ShortcutBindings.MouseAction) {
        switch action {
        case .togglePauseResume:
            delegate?.togglePauseResume()
        case .reset:
            delegate?.resetTimer()
        case .none:
            break
        }
    }
}
