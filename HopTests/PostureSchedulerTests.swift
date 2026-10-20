import XCTest
@testable import Hop

final class MockClock: Clock {
    var current: Date
    init(_ d: Date) { self.current = d }
    func now() -> Date { current }
}

final class StubNotificationManager: NotificationScheduling, @unchecked Sendable {
    var scheduled: [(posture: Posture, date: Date)] = []
    var cancelCount = 0
    func schedule(nextPosture: Posture, fireAt: Date) {
        scheduled.append((nextPosture, fireAt))
    }
    func cancelAll() { cancelCount += 1 }
}

@MainActor
final class PostureSchedulerTests: XCTestCase {
    private var settingsStore: SettingsStore!
    private var history: HistoryStore!
    private var notif: StubNotificationManager!
    private var clock: MockClock!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var settingsSuiteName: String!
    private var scheduler: PostureScheduler!

    override func setUp() async throws {
        suiteName = "hop.tests.scheduler.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settingsSuiteName = "hop.tests.settings.\(UUID().uuidString)"
        settingsStore = SettingsStore(defaults: UserDefaults(suiteName: settingsSuiteName)!)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hop-\(UUID().uuidString).json")
        history = HistoryStore(fileURL: url)
        notif = StubNotificationManager()
        // 2026-04-20 Monday 10:00
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 20; c.hour = 10
        clock = MockClock(Calendar.current.date(from: c)!)
        scheduler = PostureScheduler(
            settingsStore: settingsStore,
            history: history,
            notifications: notif,
            clock: clock,
            defaults: defaults
        )
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        UserDefaults().removePersistentDomain(forName: settingsSuiteName)
    }

    private func at(hour: Int, minute: Int = 0) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 20; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    func test_initialPosture_isSitting() {
        XCTAssertEqual(scheduler.currentPosture, .sitting)
    }

    func test_initialSchedule_setsNextTransition_duringWorkHours() {
        XCTAssertNotNil(scheduler.nextTransitionAt)
        let delta = scheduler.nextTransitionAt!.timeIntervalSince(clock.now())
        // Default science mode = 30 min sit
        XCTAssertEqual(delta, 30 * 60, accuracy: 2)
    }

    func test_switchedAction_flipsPosture_andLogs() {
        scheduler.handleNotificationAction(.switched, nextPosture: .standing)
        XCTAssertEqual(scheduler.currentPosture, .standing)
        XCTAssertTrue(history.events.contains { $0.trigger == .notificationAction && $0.posture == .standing })
    }

    func test_switchedAction_reschedules_withStandDuration() {
        scheduler.handleNotificationAction(.switched, nextPosture: .standing)
        let delta = scheduler.nextTransitionAt!.timeIntervalSince(clock.now())
        XCTAssertEqual(delta, 30 * 60, accuracy: 2) // science = 30 min stand
    }

    func test_skipAction_doesNotChangePosture_butLogsSkip() {
        scheduler.handleNotificationAction(.skip, nextPosture: .standing)
        XCTAssertEqual(scheduler.currentPosture, .sitting)
        XCTAssertTrue(history.events.contains { $0.trigger == .skipped })
    }

    func test_snoozeAction_reschedules10Minutes() {
        scheduler.handleNotificationAction(.snooze, nextPosture: .standing)
        let delta = scheduler.nextTransitionAt!.timeIntervalSince(clock.now())
        XCTAssertEqual(delta, 600, accuracy: 2)
    }

    func test_manualTransition_logsAndReschedules() {
        scheduler.markManualTransition(to: .standing)
        XCTAssertEqual(scheduler.currentPosture, .standing)
        XCTAssertTrue(history.events.contains { $0.trigger == .manual })
        XCTAssertNotNil(scheduler.nextTransitionAt)
    }

    func test_offHours_noNextTransition_cancelsNotifications() {
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 20; c.hour = 23
        clock.current = Calendar.current.date(from: c)!
        let before = notif.cancelCount
        scheduler.reschedule()
        XCTAssertNil(scheduler.nextTransitionAt)
        XCTAssertGreaterThan(notif.cancelCount, before)
    }

    func test_pauseForToday_setsPauseUntilEndOfDay() {
        scheduler.pauseForToday()
        let paused = settingsStore.settings.pausedUntil
        XCTAssertNotNil(paused)
        XCTAssertTrue(paused! > clock.now())
    }

    func test_clearPause_resumesScheduling() {
        scheduler.pauseForToday()
        scheduler.reschedule()
        XCTAssertNil(scheduler.nextTransitionAt)
        scheduler.clearPause()
        scheduler.reschedule()
        XCTAssertNotNil(scheduler.nextTransitionAt)
    }

    func test_reschedule_afterSettingsChange_picksUpNewMode() {
        settingsStore.settings.mode = .beginner
        scheduler.reschedule()
        let delta = scheduler.nextTransitionAt!.timeIntervalSince(clock.now())
        XCTAssertEqual(delta, 45 * 60, accuracy: 2) // beginner = 45 min sit
    }

    func test_autoStart_logsSittingEvent_onFirstBootOfDay() {
        let autoStarts = history.events.filter { $0.trigger == .autoStart }
        XCTAssertEqual(autoStarts.count, 1)
        XCTAssertEqual(autoStarts.first?.posture, .sitting)
    }

    func test_reminderPastLunch_isNotScheduled() {
        clock.current = at(hour: 11, minute: 50)
        scheduler.reschedule()
        XCTAssertNil(scheduler.nextTransitionAt)
        XCTAssertEqual(scheduler.status, .working)
    }

    func test_refresh_atStartOfWork_schedulesReminder() {
        clock.current = at(hour: 8)
        scheduler.reschedule()
        XCTAssertNil(scheduler.nextTransitionAt)

        clock.current = at(hour: 9)
        scheduler.refresh()
        XCTAssertEqual(scheduler.status, .working)
        XCTAssertEqual(scheduler.nextTransitionAt!.timeIntervalSince(clock.now()), 30 * 60, accuracy: 2)
    }

    func test_refresh_afterLunchStarts_cancelsReminder() {
        clock.current = at(hour: 11, minute: 20)
        scheduler.reschedule()
        XCTAssertNotNil(scheduler.nextTransitionAt)

        clock.current = at(hour: 12)
        scheduler.refresh()
        XCTAssertEqual(scheduler.status, .onLunchBreak)
        XCTAssertNil(scheduler.nextTransitionAt)
    }

    func test_wake_keepsRunningCountdown() {
        let target = scheduler.nextTransitionAt
        clock.current = clock.now().addingTimeInterval(5 * 60)
        scheduler.handleWake()
        XCTAssertEqual(scheduler.nextTransitionAt, target)
    }

    func test_wake_onNextDay_reschedules() {
        let target = scheduler.nextTransitionAt
        clock.current = at(hour: 10).addingTimeInterval(24 * 3600)
        scheduler.handleWake()
        XCTAssertNotEqual(scheduler.nextTransitionAt, target)
        XCTAssertEqual(scheduler.nextTransitionAt!.timeIntervalSince(clock.now()), 30 * 60, accuracy: 2)
    }

    func test_snooze_outsideWorkHours_isIgnored() {
        clock.current = at(hour: 20)
        scheduler.reschedule()
        let before = notif.scheduled.count
        scheduler.handleNotificationAction(.snooze, nextPosture: .standing)
        XCTAssertEqual(notif.scheduled.count, before)
        XCTAssertNil(scheduler.nextTransitionAt)
    }

    func test_autoStart_notLogged_outsideWorkHours() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hop-\(UUID().uuidString).json")
        let freshHistory = HistoryStore(fileURL: url)
        clock.current = at(hour: 7)
        let freshSuite = "hop.tests.fresh.\(UUID().uuidString)"
        let freshDefaults = UserDefaults(suiteName: freshSuite)!
        defer { freshDefaults.removePersistentDomain(forName: freshSuite) }
        _ = PostureScheduler(
            settingsStore: settingsStore,
            history: freshHistory,
            notifications: notif,
            clock: clock,
            defaults: freshDefaults
        )
        XCTAssertTrue(freshHistory.events.isEmpty)
    }

    func test_snoozeAction_schedulesNotificationFor10Minutes() {
        let before = notif.scheduled.count
        scheduler.handleNotificationAction(.snooze, nextPosture: .standing)
        XCTAssertEqual(notif.scheduled.count, before + 1)
        let last = notif.scheduled.last!
        XCTAssertEqual(last.posture, .standing)
        XCTAssertEqual(last.date.timeIntervalSince(clock.now()), 600, accuracy: 2)
    }
}
