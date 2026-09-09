import Foundation

struct TimerState: Codable {
    var accumulated: TimeInterval = 0
    var previousTimestamp: TimeInterval = Date().timeIntervalSince1970
    var isRunning: Bool = true

    var currentElapsed: TimeInterval {
        if isRunning {
            return accumulated + elapsedSincePreviousTimestamp()
        } else {
            return accumulated
        }
    }

    mutating func start() {
        if !isRunning {
            previousTimestamp = Date().timeIntervalSince1970
            isRunning = true
        }
    }

    mutating func pause() {
        if isRunning {
            accumulated += elapsedSincePreviousTimestamp()
            previousTimestamp = Date().timeIntervalSince1970
            isRunning = false
        }
    }

    mutating func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    mutating func reset() {
        accumulated = 0
        previousTimestamp = Date().timeIntervalSince1970
    }

    mutating func setTime(_ seconds: TimeInterval) {
        accumulated = max(0, seconds)
        previousTimestamp = Date().timeIntervalSince1970
    }

    mutating func resumeFromPersistence() {
        if isRunning {
            accumulated += elapsedSincePreviousTimestamp()
            previousTimestamp = Date().timeIntervalSince1970
        }
    }

    /// Wall-clock time since `previousTimestamp`, never negative.
    ///
    /// The timer is wall-clock based so it keeps counting through sleep and app
    /// restarts. The cost is that a clock adjustment backwards (NTP sync, manual
    /// change, time zone edge cases) would otherwise produce a negative delta and
    /// silently subtract from the accumulated time.
    private func elapsedSincePreviousTimestamp() -> TimeInterval {
        max(0, Date().timeIntervalSince1970 - previousTimestamp)
    }
}
