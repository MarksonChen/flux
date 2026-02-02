import AppKit

protocol ShortcutManagerDelegate: AnyObject {
    func togglePauseResume()
    func copyTime()
    func openSetTime()
    func openHistory()
    func openSettings()
    func resetTimer()
    func quit()
}

final class ShortcutManager {
    static let shared = ShortcutManager()
    weak var delegate: ShortcutManagerDelegate?

    private init() {}

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
