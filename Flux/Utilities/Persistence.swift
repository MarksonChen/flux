import AppKit

final class Persistence {
    static let shared = Persistence()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let timerState = "timerState"
        static let appSettings = "appSettings"
        static let shortcutBindings = "shortcutBindings"
        static let globalShortcutBindings = "globalShortcutBindings"
        static let timerEvents = "timerEvents"
        static let windowX = "windowX"
        static let windowY = "windowY"
        static let windowDisplayID = "windowDisplayID"
    }

    private init() {}

    // MARK: - Timer State

    var timerState: TimerState {
        get {
            guard let data = defaults.data(forKey: Keys.timerState),
                  let state = try? JSONDecoder().decode(TimerState.self, from: data) else {
                return TimerState()
            }
            return state
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.timerState)
            }
        }
    }

    // MARK: - App Settings

    var appSettings: AppSettings {
        get {
            guard let data = defaults.data(forKey: Keys.appSettings),
                  let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
                return AppSettings.default
            }
            return settings
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.appSettings)
            }
        }
    }

    // MARK: - Shortcut Bindings

    var shortcutBindings: ShortcutBindings {
        get {
            guard let data = defaults.data(forKey: Keys.shortcutBindings),
                  let bindings = try? JSONDecoder().decode(ShortcutBindings.self, from: data) else {
                return ShortcutBindings.default
            }
            return bindings
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.shortcutBindings)
            }
        }
    }

    // MARK: - Global Shortcut Bindings

    var globalShortcutBindings: GlobalShortcutBindings {
        get {
            guard let data = defaults.data(forKey: Keys.globalShortcutBindings),
                  let bindings = try? JSONDecoder().decode(GlobalShortcutBindings.self, from: data) else {
                return GlobalShortcutBindings.default
            }
            return bindings
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.globalShortcutBindings)
            }
        }
    }

    // MARK: - Timer Events

    var timerEvents: [TimerEvent] {
        get {
            guard let data = defaults.data(forKey: Keys.timerEvents),
                  let events = try? JSONDecoder().decode([TimerEvent].self, from: data) else {
                return []
            }
            return events
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.timerEvents)
            }
        }
    }

    // MARK: - Window Position

    var windowPosition: NSPoint? {
        get {
            guard defaults.object(forKey: Keys.windowX) != nil else { return nil }
            let x = defaults.double(forKey: Keys.windowX)
            let y = defaults.double(forKey: Keys.windowY)
            return NSPoint(x: x, y: y)
        }
        set {
            if let point = newValue {
                defaults.set(point.x, forKey: Keys.windowX)
                defaults.set(point.y, forKey: Keys.windowY)
            } else {
                defaults.removeObject(forKey: Keys.windowX)
                defaults.removeObject(forKey: Keys.windowY)
            }
        }
    }

    var windowDisplayID: CGDirectDisplayID? {
        get {
            guard defaults.object(forKey: Keys.windowDisplayID) != nil else { return nil }
            return CGDirectDisplayID(defaults.integer(forKey: Keys.windowDisplayID))
        }
        set {
            if let id = newValue {
                defaults.set(Int(id), forKey: Keys.windowDisplayID)
            } else {
                defaults.removeObject(forKey: Keys.windowDisplayID)
            }
        }
    }

    // MARK: - Reset

    func resetSettings() {
        appSettings = AppSettings.default
    }

    func resetShortcuts() {
        shortcutBindings = ShortcutBindings.default
    }

    func resetGlobalShortcuts() {
        globalShortcutBindings = GlobalShortcutBindings.default
    }

    func resetHistory() {
        timerEvents = []
    }
}
