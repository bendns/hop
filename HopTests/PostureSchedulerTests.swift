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
    private var scheduler: PostureScheduler!

    override func setUp() {
        super.setUp()
        suiteName = "hop.tests.scheduler.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        let settingsSuite = "hop.tests.settings.\(UUID().uuidString)"
        settingsStore = SettingsStore(defaults: UserDefaults(suiteName: settingsSuite)!)
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

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
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
        settingsStore.settings.mode = .advanced
        scheduler.reschedule()
        // Advanced sitting → 30 min sit (same as science). Mode change takes effect
        // on next transition. Verify it's still scheduled.
        XCTAssertNotNil(scheduler.nextTransitionAt)
    }

    func test_autoStart_logsSittingEvent_onFirstBootOfDay() {
        let autoStarts = history.events.filter { $0.trigger == .autoStart }
        XCTAssertEqual(autoStarts.count, 1)
        XCTAssertEqual(autoStarts.first?.posture, .sitting)
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
