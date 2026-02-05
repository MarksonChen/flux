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

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var accessibilityPollTimer: Timer?

    private init() {}

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

    private func registerEventTap() {
        // Create event tap for keyDown events
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                return ShortcutManager.shared.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            print("Failed to create event tap")
            return
        }

        eventTap = tap

        // Create run loop source and add to current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled events (system may disable tap if it's too slow)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let bindings = Persistence.shared.globalShortcutBindings
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Convert CGEventFlags to modifier mask
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)
        let hasCommand = flags.contains(.maskCommand)

        // Check Copy + Reset shortcut
        if bindings.copyAndResetEnabled {
            let expectedFlags = bindings.copyAndResetModifierFlags
            let matchControl = expectedFlags.contains(.control) == hasControl
            let matchOption = expectedFlags.contains(.option) == hasOption
            let matchShift = expectedFlags.contains(.shift) == hasShift
            let matchCommand = expectedFlags.contains(.command) == hasCommand

            if keyCode == bindings.copyAndResetKeyCode && matchControl && matchOption && matchShift && matchCommand {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.copyAndReset()
                }
                return nil  // Consume the event
            }
        }

        // Check Toggle shortcut
        if bindings.toggleEnabled {
            let expectedFlags = bindings.toggleModifierFlags
            let matchControl = expectedFlags.contains(.control) == hasControl
            let matchOption = expectedFlags.contains(.option) == hasOption
            let matchShift = expectedFlags.contains(.shift) == hasShift
            let matchCommand = expectedFlags.contains(.command) == hasCommand

            if keyCode == bindings.toggleKeyCode && matchControl && matchOption && matchShift && matchCommand {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.togglePauseResume()
                }
                return nil  // Consume the event
            }
        }

        // Pass through unmatched events
        return Unmanaged.passRetained(event)
    }

    private func startAccessibilityPolling() {
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if AXIsProcessTrusted() {
                self?.accessibilityPollTimer?.invalidate()
                self?.accessibilityPollTimer = nil
                self?.registerEventTap()
                self?.showAccessibilityGrantedAlert()
            }
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

    func stopGlobalMonitoring() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        let bindings = Persistence.shared.shortcutBindings
        let chars = event.charactersIgnoringModifiers ?? ""
        let hasCommand = event.modifierFlags.contains(.command)

        if hasCommand {
            switch chars.lowercased() {
            case bindings.copyTime:
                delegate?.copyTime()
                return true
            case bindings.openSetTime:
                delegate?.openSetTime()
                return true
            case bindings.openHistory:
                delegate?.openHistory()
                return true
            case bindings.openSettings:
                delegate?.openSettings()
                return true
            case bindings.quit:
                delegate?.quit()
                return true
            default:
                break
            }
        } else {
            if chars == bindings.togglePauseResume {
                delegate?.togglePauseResume()
                return true
            }
        }

        return false
    }

    func handleLeftClick() {
        let bindings = Persistence.shared.shortcutBindings
        performMouseAction(bindings.leftClickAction)
    }

    func handleRightClick() {
        let bindings = Persistence.shared.shortcutBindings
        performMouseAction(bindings.rightClickAction)
    }

    func handleLeftDoubleClick() {
        let bindings = Persistence.shared.shortcutBindings
        performMouseAction(bindings.leftDoubleClickAction)
    }

    func handleRightDoubleClick() {
        let bindings = Persistence.shared.shortcutBindings
        performMouseAction(bindings.rightDoubleClickAction)
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
