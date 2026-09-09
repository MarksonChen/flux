import AppKit

/// UserDefaults wrapper for all app state.
///
/// Every JSON-backed value is cached in memory and written through on set. The
/// getters are hit on hot paths (every system-wide key press in the global event
/// tap, every click, every fullscreen check), so decoding from UserDefaults on
/// each read is avoided. This app is the only writer of its defaults, so the
/// cache never goes stale.
final class Persistence {
    static let shared = Persistence()

    /// Posted on the main thread after `timerEvents` changes.
    static let timerEventsDidChange = Notification.Name("Persistence.timerEventsDidChange")

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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

    // MARK: - Cached values

    private lazy var cachedTimerState: TimerState = load(Keys.timerState, default: TimerState())
    private lazy var cachedAppSettings: AppSettings = load(Keys.appSettings, default: .default)
    private lazy var cachedShortcutBindings: ShortcutBindings = load(Keys.shortcutBindings, default: .default)
    private lazy var cachedGlobalShortcutBindings: GlobalShortcutBindings = load(Keys.globalShortcutBindings, default: .default)
    private lazy var cachedTimerEvents: [TimerEvent] = load(Keys.timerEvents, default: [])

    private func load<T: Decodable>(_ key: String, default defaultValue: T) -> T {
        guard let data = defaults.data(forKey: key),
              let value = try? decoder.decode(T.self, from: data) else {
            return defaultValue
        }
        return value
    }

    private func store<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - Timer State

    var timerState: TimerState {
        get { cachedTimerState }
        set {
            cachedTimerState = newValue
            store(newValue, forKey: Keys.timerState)
        }
    }

    // MARK: - App Settings

    var appSettings: AppSettings {
        get { cachedAppSettings }
        set {
            cachedAppSettings = newValue
            store(newValue, forKey: Keys.appSettings)
        }
    }

    // MARK: - Shortcut Bindings

    var shortcutBindings: ShortcutBindings {
        get { cachedShortcutBindings }
        set {
            cachedShortcutBindings = newValue
            store(newValue, forKey: Keys.shortcutBindings)
        }
    }

    // MARK: - Global Shortcut Bindings

    var globalShortcutBindings: GlobalShortcutBindings {
        get { cachedGlobalShortcutBindings }
        set {
            cachedGlobalShortcutBindings = newValue
            store(newValue, forKey: Keys.globalShortcutBindings)
        }
    }

    // MARK: - Timer Events

    var timerEvents: [TimerEvent] {
        get { cachedTimerEvents }
        set {
            cachedTimerEvents = newValue
            store(newValue, forKey: Keys.timerEvents)
            NotificationCenter.default.post(name: Persistence.timerEventsDidChange, object: self)
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

    /// Restores font, size, color and opacity. General settings are untouched so a
    /// registered login item never goes out of sync with its checkbox.
    func resetAppearance() {
        appSettings = appSettings.resettingAppearance()
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
