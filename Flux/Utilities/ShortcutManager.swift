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

    private var globalMonitor: Any?
    private var accessibilityPollTimer: Timer?

    private init() {}

    func startGlobalMonitoring() {
        stopGlobalMonitoring()

        // First check if already trusted (without prompting)
        if AXIsProcessTrusted() {
            registerGlobalMonitor()
            return
        }

        // Not trusted yet - prompt the user
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )

        // Poll until permission is granted
        startAccessibilityPolling()
    }

    private func registerGlobalMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKeyDown(event)
        }
    }

    private func startAccessibilityPolling() {
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if AXIsProcessTrusted() {
                self?.accessibilityPollTimer?.invalidate()
                self?.accessibilityPollTimer = nil
                self?.registerGlobalMonitor()
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

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func handleGlobalKeyDown(_ event: NSEvent) {
        let bindings = Persistence.shared.globalShortcutBindings

        guard bindings.copyAndResetEnabled else { return }

        let modifierMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let pressedModifiers = event.modifierFlags.intersection(modifierMask)
        let expectedModifiers = bindings.copyAndResetModifierFlags.intersection(modifierMask)

        if event.keyCode == bindings.copyAndResetKeyCode && pressedModifiers == expectedModifiers {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.copyAndReset()
            }
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
