import AppKit
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
        updateDisplay()
        scheduleNextTick()
    }

    // MARK: - Display updates

    /// The display only changes once per second, so instead of polling on a fixed
    /// interval a one-shot timer is armed to fire just after the next whole-second
    /// boundary of the elapsed time. That keeps the flip within a few milliseconds
    /// of the true boundary, wakes up 1x/s instead of 10x/s, and stops entirely
    /// while the timer is paused.
    private func scheduleNextTick() {
        displayTimer?.invalidate()
        displayTimer = nil

        guard state.isRunning else { return }

        let fraction = state.currentElapsed.truncatingRemainder(dividingBy: 1)
        let delay = (1 - fraction) + 0.005

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func tick() {
        updateDisplay()
        scheduleNextTick()
    }

    private func updateDisplay() {
        let formatted = TimeFormatter.format(state.currentElapsed)
        // Only publish real changes so subscribers do not relayout needlessly.
        if formatted != displayTime {
            displayTime = formatted
        }
    }

    private func save() {
        Persistence.shared.timerState = state
    }

    // MARK: - State

    var currentElapsed: TimeInterval {
        state.currentElapsed
    }

    var isRunning: Bool {
        state.isRunning
    }

    // MARK: - Actions

    func togglePauseResume() {
        let elapsed = state.currentElapsed
        if state.isRunning {
            state.pause()
            eventLogger.logPaused(at: elapsed)
        } else {
            state.start()
            eventLogger.logStarted(at: elapsed)
        }
        didMutateState()
    }

    func reset() {
        let previousTime = state.currentElapsed
        state.reset()
        eventLogger.logRestarted(from: previousTime)
        didMutateState()
    }

    func setTime(_ seconds: TimeInterval) {
        let previousTime = state.currentElapsed
        state.setTime(seconds)
        eventLogger.logSet(from: previousTime, to: seconds)
        didMutateState()
    }

    func copyTimeToClipboard() {
        let minutes = TimeFormatter.roundedMinutes(state.currentElapsed)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(minutes)", forType: .string)
    }

    private func didMutateState() {
        save()
        updateDisplay()
        scheduleNextTick()
    }
}
