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

    private static let maxEntries = 100

    private func addEvent(_ event: TimerEvent) {
        var currentEvents = Persistence.shared.timerEvents
        currentEvents.insert(event, at: 0)

        if currentEvents.count > EventLogger.maxEntries {
            currentEvents = Array(currentEvents.prefix(EventLogger.maxEntries))
        }

        Persistence.shared.timerEvents = currentEvents
    }

    func clearHistory() {
        Persistence.shared.timerEvents = []
    }
}
