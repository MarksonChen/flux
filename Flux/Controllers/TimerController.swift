import Foundation
import Combine

final class TimerController: ObservableObject {
    static let shared = TimerController()

    @Published private(set) var state: TimerState
    @Published private(set) var displayTime: String = "00:00"

    private var displayTimer: Timer?
    private let eventLogger = EventLogger.shared

    private init() {
        var savedState = Persistence.shared.timerState
        savedState.resumeFromPersistence()
        self.state = savedState
        startDisplayTimer()
        updateDisplay()
    }

    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
        RunLoop.main.add(displayTimer!, forMode: .common)
    }

    private func updateDisplay() {
        displayTime = TimeFormatter.format(state.currentElapsed)
    }

    private func save() {
        Persistence.shared.timerState = state
    }

    var currentElapsed: TimeInterval {
        state.currentElapsed
    }

    var isRunning: Bool {
        state.isRunning
    }

    func togglePauseResume() {
        let elapsed = state.currentElapsed
        if state.isRunning {
            state.pause()
            eventLogger.logPaused(at: elapsed)
        } else {
            state.start()
            eventLogger.logStarted(at: elapsed)
        }
        save()
        updateDisplay()
    }

    func reset() {
        let previousTime = state.currentElapsed
        state.reset()
        eventLogger.logRestarted(from: previousTime)
        save()
        updateDisplay()
    }

    func setTime(_ seconds: TimeInterval) {
        let previousTime = state.currentElapsed
        state.setTime(seconds)
        eventLogger.logSet(from: previousTime, to: seconds)
        save()
        updateDisplay()
    }

    func copyTimeToClipboard() {
        let minutes = TimeFormatter.roundedMinutes(state.currentElapsed)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(minutes)", forType: .string)
    }
}

import AppKit
