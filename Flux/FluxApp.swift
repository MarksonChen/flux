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
        positionWindowAboveTimer(setTimeController?.window)
        setTimeController?.showWindow(nil)
        setTimeController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openHistory() {
        if historyController == nil {
            historyController = HistoryWindowController()
        }
        historyController?.refreshEvents()
        positionWindowAboveTimer(historyController?.window)
        historyController?.showWindow(nil)
        historyController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
            settingsController?.delegate = self
        }
        positionWindowAboveTimer(settingsController?.window)
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func positionWindowAboveTimer(_ window: NSWindow?) {
        guard let window = window else { return }
        // Position window above the timer with 10 pixel gap
        let newOrigin = NSPoint(
            x: timerWindow.frame.midX - window.frame.width / 2,
            y: timerWindow.frame.maxY + 10
        )
        window.setFrameOrigin(newOrigin)
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
