import Foundation

struct TimeFormatter {
    static func format(_ interval: TimeInterval) -> String {
        let totalSeconds = wholeSeconds(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    static func roundedMinutes(_ interval: TimeInterval) -> Int {
        let totalSeconds = wholeSeconds(interval)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return remainingSeconds >= 30 ? minutes + 1 : minutes
    }

    /// Truncates to whole seconds, treating negative or non-finite input as zero.
    /// `Int(_:)` traps on NaN/infinity, so guard before converting.
    private static func wholeSeconds(_ interval: TimeInterval) -> Int {
        guard interval.isFinite, interval > 0 else { return 0 }
        return Int(min(interval, TimeInterval(Int.max / 2)))
    }
}
