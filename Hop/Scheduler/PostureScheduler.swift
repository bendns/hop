import Foundation
import Combine
import AppKit

protocol Clock {
    func now() -> Date
}

struct SystemClock: Clock {
    func now() -> Date { Date() }
}

@MainActor
final class PostureScheduler: ObservableObject {
    static let shared = PostureScheduler()

    @Published private(set) var currentPosture: Posture = .sitting
    @Published private(set) var nextTransitionAt: Date?
    @Published private(set) var status: ScheduleStatus = .outsideWorkHours

    private let settingsStore: SettingsStore
    private let history: HistoryStore
    private let notifications: any NotificationScheduling
    private let evaluator: ScheduleEvaluator
    private let clock: Clock
    private let defaults: UserDefaults

    private var cancellables = Set<AnyCancellable>()
    private let lastPostureKey = "hop.lastPosture.v1"
    private let lastPostureDateKey = "hop.lastPostureDate.v1"

    init(
        settingsStore: SettingsStore = .shared,
        history: HistoryStore = .shared,
        notifications: any NotificationScheduling = NotificationManager.shared,
        evaluator: ScheduleEvaluator = ScheduleEvaluator(),
        clock: Clock = SystemClock(),
        defaults: UserDefaults = .standard
    ) {
        self.settingsStore = settingsStore
        self.history = history
        self.notifications = notifications
        self.evaluator = evaluator
        self.clock = clock
        self.defaults = defaults
        restorePosture()
        observeSettings()
        reschedule()
    }

    // MARK: - Public actions

    func markManualTransition(to posture: Posture) {
        currentPosture = posture
        history.record(PostureEvent(timestamp: clock.now(), posture: posture, trigger: .manual))
        persistPosture()
        reschedule()
    }

    func handleNotificationAction(_ action: NotificationAction, nextPosture: Posture) {
        switch action {
        case .switched:
            currentPosture = nextPosture
            history.record(PostureEvent(timestamp: clock.now(), posture: nextPosture, trigger: .notificationAction))
            persistPosture()
            reschedule()
        case .snooze:
            scheduleNext(at: clock.now().addingTimeInterval(10 * 60), nextPosture: nextPosture)
        case .skip:
            history.record(PostureEvent(timestamp: clock.now(), posture: currentPosture, trigger: .skipped))
            reschedule()
        }
    }

    func pauseForToday() {
        let cal = Calendar.current
        let endOfDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: clock.now()))!
        settingsStore.settings.pausedUntil = endOfDay
    }

    func clearPause() {
        settingsStore.settings.pausedUntil = nil
    }

    /// Call on wake from sleep.
    func handleWake() { reschedule() }

    // MARK: - Internal

    func reschedule() {
        let now = clock.now()
        status = evaluator.status(at: now, settings: settingsStore.settings)

        resetPostureIfNewDay(now: now)

        guard status == .working else {
            nextTransitionAt = nil
            notifications.cancelAll()
            return
        }

        let durations = Presets.durations(
            for: settingsStore.settings.mode,
            custom: Durations(
                standMinutes: settingsStore.settings.customStandMinutes,
                sitMinutes: settingsStore.settings.customSitMinutes
            )
        )
        let minutes = currentPosture == .sitting ? durations.sitMinutes : durations.standMinutes
        let target = now.addingTimeInterval(TimeInterval(minutes * 60))
        scheduleNext(at: target, nextPosture: currentPosture.toggled)
    }

    private func scheduleNext(at date: Date, nextPosture: Posture) {
        nextTransitionAt = date
        notifications.schedule(nextPosture: nextPosture, fireAt: date)
    }

    private func observeSettings() {
        // Debounce coalesces Stepper-drag storms into one reschedule.
        // The main-queue scheduler also defers past @Published's willSet,
        // so `reschedule` reads the committed Settings value.
        settingsStore.$settings
            .dropFirst()
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.reschedule() }
            .store(in: &cancellables)
    }

    private func resetPostureIfNewDay(now: Date) {
        let cal = Calendar.current
        let lastDate = defaults.object(forKey: lastPostureDateKey) as? Date
        if lastDate == nil || !cal.isDate(lastDate!, inSameDayAs: now) {
            currentPosture = .sitting
            history.record(PostureEvent(timestamp: now, posture: .sitting, trigger: .autoStart))
            persistPosture()
        }
    }

    private func restorePosture() {
        if let raw = defaults.string(forKey: lastPostureKey),
           let posture = Posture(rawValue: raw) {
            currentPosture = posture
        }
    }

    private func persistPosture() {
        defaults.set(currentPosture.rawValue, forKey: lastPostureKey)
        defaults.set(clock.now(), forKey: lastPostureDateKey)
    }
}
