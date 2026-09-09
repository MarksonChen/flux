import AppKit

@main
class FluxApp: NSObject, NSApplicationDelegate {
    private var timerWindow: TimerWindow!
    private var setTimeController: SetTimeWindowController?
    private var historyController: HistoryWindowController?
    private var settingsController: SettingsWindowController?

    static func main() {
        let app = NSApplication.shared
        let delegate = FluxApp()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()

        timerWindow = TimerWindow()
        timerWindow.makeKeyAndOrderFront(nil)

        ShortcutManager.shared.delegate = self
        ShortcutManager.shared.startGlobalMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Persistence.shared.timerState = TimerController.shared.state
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// An accessory app has no visible menu bar, but standard editing key
    /// equivalents (⌘C, ⌘V, ⌘A, ⌘Z) are dispatched through the main menu. Without
    /// an Edit menu they do nothing inside the Set Time text fields.
    ///
    /// The items are only enabled while a text field is being edited, so in the
    /// timer window the same keys still fall through to the configurable
    /// shortcuts. Quit is deliberately not added here so the user's Quit binding
    /// stays authoritative.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}

extension FluxApp: ShortcutManagerDelegate {
    func togglePauseResume() {
        TimerController.shared.togglePauseResume()
    }

    func copyTime() {
        TimerController.shared.copyTimeToClipboard()
    }

    func openSetTime() {
        if setTimeController == nil {
            setTimeController = SetTimeWindowController()
        }
        setTimeController?.resetToZero()
        present(setTimeController)
    }

    func openHistory() {
        if historyController == nil {
            historyController = HistoryWindowController()
        }
        historyController?.refreshEvents()
        present(historyController)
    }

    func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
            settingsController?.delegate = self
        }
        present(settingsController)
    }

    private func present(_ controller: NSWindowController?) {
        guard let controller else { return }
        positionWindowAboveTimer(controller.window)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Places a dialog centered above the timer with a small gap. Falls back to
    /// below the timer when there is no room above, and keeps the whole dialog
    /// inside the timer's screen so it never opens off-screen.
    private func positionWindowAboveTimer(_ window: NSWindow?) {
        guard let window = window else { return }
        let gap: CGFloat = 10
        let timerFrame = timerWindow.frame
        let size = window.frame.size

        var origin = NSPoint(
            x: timerFrame.midX - size.width / 2,
            y: timerFrame.maxY + gap
        )

        if let screen = timerWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if origin.y + size.height > visible.maxY {
                origin.y = timerFrame.minY - gap - size.height
            }
            origin.x = min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - size.width))
            origin.y = min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - size.height))
        }

        window.setFrameOrigin(origin)
    }

    func resetTimer() {
        TimerController.shared.reset()
    }

    func copyAndReset() {
        TimerController.shared.copyTimeToClipboard()
        TimerController.shared.reset()
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

extension FluxApp: SettingsWindowDelegate {
    func settingsDidChange() {
        timerWindow.refreshAppearance()
    }
}
