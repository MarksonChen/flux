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
        setTimeController?.showWindow(nil)
        setTimeController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openHistory() {
        if historyController == nil {
            historyController = HistoryWindowController()
        }
        historyController?.showWindow(nil)
        historyController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
            settingsController?.delegate = self
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func resetTimer() {
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
