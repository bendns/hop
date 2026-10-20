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
    /// When the countdown to `nextTransitionAt` started, for progress display.
    @Published private(set) var transitionStartedAt: Date?
    @Published private(set) var status: ScheduleStatus = .outsideWorkHours

    private let settingsStore: SettingsStore
    private let history: HistoryStore
    private let notifications: any NotificationScheduling
    private let evaluator: ScheduleEvaluator
    private let clock: Clock
    private let defaults: UserDefaults

    private var cancellables = Set<AnyCancellable>()
    /// `status` holds until this moment; `statusTimer` fires then to re-evaluate.
    @Published private(set) var statusValidUntil: Date?
    private var statusTimer: Task<Void, Never>?
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
            guard status == .working else { return }
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
    func handleWake() { refresh() }

    /// Re-evaluates the schedule without restarting a countdown that is still valid,
    /// i.e. when no status change happened since it was scheduled.
    func refresh() {
        if nextTransitionAt != nil, let until = statusValidUntil, clock.now() < until {
            return
        }
        reschedule()
    }

    // MARK: - Internal

    func reschedule() {
        let now = clock.now()
        status = evaluator.status(at: now, settings: settingsStore.settings)

        statusValidUntil = evaluator.nextStatusChange(after: now, settings: settingsStore.settings)
        armStatusTimer(now: now)

        resetPostureIfNewDay(now: now)

        guard status == .working else {
            nextTransitionAt = nil
            notifications.cancelAll()
            return
        }

        if history.eventsForToday(now: now).isEmpty {
            history.record(PostureEvent(timestamp: now, posture: currentPosture, trigger: .autoStart))
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

    /// Schedules the reminder, unless it would land after the current working stretch
    /// (lunch, end of day, pause, vacation): the status timer takes over from there.
    private func scheduleNext(at date: Date, nextPosture: Posture) {
        if let until = statusValidUntil, date >= until {
            nextTransitionAt = nil
            notifications.cancelAll()
            return
        }
        nextTransitionAt = date
        transitionStartedAt = clock.now()
        notifications.schedule(nextPosture: nextPosture, fireAt: date)
    }

    private func armStatusTimer(now: Date) {
        statusTimer?.cancel()
        guard let until = statusValidUntil else { return }
        // One extra second so the evaluator, which works at minute granularity,
        // sees the new status when the timer fires.
        let delay = until.timeIntervalSince(now) + 1
        statusTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
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
