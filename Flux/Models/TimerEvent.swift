import Foundation

enum TimerEventType: String, Codable {
    case started = "Started"
    case paused = "Paused"
    case restarted = "Restarted"
    case set = "Set"
}

struct TimerEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let eventType: TimerEventType
    let timeValue: TimeInterval
    let previousValue: TimeInterval?

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter
    }()

    init(eventType: TimerEventType, timeValue: TimeInterval, previousValue: TimeInterval? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.eventType = eventType
        self.timeValue = timeValue
        self.previousValue = previousValue
    }

    var formattedTimestamp: String {
        Self.timestampFormatter.string(from: timestamp)
    }

    var formattedChange: String {
        let timeStr = TimeFormatter.format(timeValue)
        switch eventType {
        case .started:
            return "\(timeStr) ▶"
        case .paused:
            return "\(timeStr) ⏸"
        case .restarted:
            let prevStr = TimeFormatter.format(previousValue ?? 0)
            return "\(prevStr) → 00:00"
        case .set:
            let prevStr = TimeFormatter.format(previousValue ?? 0)
            return "\(prevStr) → \(timeStr)"
        }
    }
}
