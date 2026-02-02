import Foundation

final class EventLogger {
    static let shared = EventLogger()

    private init() {}

    var events: [TimerEvent] {
        Persistence.shared.timerEvents
    }

    func logStarted(at time: TimeInterval) {
        addEvent(TimerEvent(eventType: .started, timeValue: time))
    }

    func logPaused(at time: TimeInterval) {
        addEvent(TimerEvent(eventType: .paused, timeValue: time))
    }

    func logRestarted(from previousTime: TimeInterval) {
        addEvent(TimerEvent(eventType: .restarted, timeValue: 0, previousValue: previousTime))
    }

    func logSet(from previousTime: TimeInterval, to newTime: TimeInterval) {
        addEvent(TimerEvent(eventType: .set, timeValue: newTime, previousValue: previousTime))
    }

    private func addEvent(_ event: TimerEvent) {
        var currentEvents = Persistence.shared.timerEvents
        currentEvents.insert(event, at: 0)

        let maxEntries = Persistence.shared.appSettings.maxHistoryEntries
        if currentEvents.count > maxEntries {
            currentEvents = Array(currentEvents.prefix(maxEntries))
        }

        Persistence.shared.timerEvents = currentEvents
    }

    func clearHistory() {
        Persistence.shared.timerEvents = []
    }
}
