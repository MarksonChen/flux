import Foundation

struct TimerState: Codable {
    var accumulated: TimeInterval = 0
    var previousTimestamp: TimeInterval = Date().timeIntervalSince1970
    var isRunning: Bool = true

    var currentElapsed: TimeInterval {
        if isRunning {
            return accumulated + (Date().timeIntervalSince1970 - previousTimestamp)
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
            accumulated += Date().timeIntervalSince1970 - previousTimestamp
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
        accumulated = seconds
        previousTimestamp = Date().timeIntervalSince1970
    }

    mutating func resumeFromPersistence() {
        if isRunning {
            let now = Date().timeIntervalSince1970
            accumulated += now - previousTimestamp
            previousTimestamp = now
        }
    }
}
