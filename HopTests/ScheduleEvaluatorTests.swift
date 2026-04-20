import XCTest
@testable import Hop

final class ScheduleEvaluatorTests: XCTestCase {
    private let evaluator = ScheduleEvaluator()
    private var settings: Settings!

    override func setUp() {
        super.setUp()
        settings = .default
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    func test_weekday_withinHours_isWorking() {
        // 2026-04-20 is a Monday.
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 10, minute: 0), settings: settings),
            .working
        )
    }

    func test_weekday_beforeStart_outsideHours() {
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 8, minute: 0), settings: settings),
            .outsideWorkHours
        )
    }

    func test_weekday_afterEnd_outsideHours() {
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 18, minute: 30), settings: settings),
            .outsideWorkHours
        )
    }

    func test_weekday_duringLunch() {
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 12, minute: 30), settings: settings),
            .onLunchBreak
        )
    }

    func test_weekday_exactlyAtLunchEnd_isWorking() {
        // Lunch ends at 13:00 (exclusive end means 13:00 is working).
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 13, minute: 0), settings: settings),
            .working
        )
    }

    func test_saturday_isDisabled() {
        // 2026-04-25 is a Saturday.
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 25, hour: 10, minute: 0), settings: settings),
            .disabled
        )
    }

    func test_officeDay_blocksNotifications() {
        settings.workHoursByWeekday[.monday]!.isOfficeDay = true
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 10, minute: 0), settings: settings),
            .officeDay
        )
    }

    func test_vacationRange_blocks() {
        let start = date(year: 2026, month: 4, day: 20, hour: 0, minute: 0)
        let end = date(year: 2026, month: 4, day: 27, hour: 0, minute: 0)
        settings.vacationRanges = [DateInterval(start: start, end: end)]
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 21, hour: 10, minute: 0), settings: settings),
            .onVacation
        )
    }

    func test_pause_blocks_untilExpiry() {
        let now = date(year: 2026, month: 4, day: 20, hour: 10, minute: 0)
        settings.pausedUntil = now.addingTimeInterval(3600)
        XCTAssertEqual(evaluator.status(at: now, settings: settings), .paused)
        XCTAssertEqual(evaluator.status(at: now.addingTimeInterval(3601), settings: settings), .working)
    }

    func test_globalDisabled_overridesAll() {
        settings.notificationsEnabled = false
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 10, minute: 0), settings: settings),
            .notificationsOff
        )
    }

    func test_nextWorkingMoment_skipsLunch() {
        let noon = date(year: 2026, month: 4, day: 20, hour: 12, minute: 30)
        let next = evaluator.nextWorkingMoment(after: noon, settings: settings)
        XCTAssertNotNil(next)
        XCTAssertEqual(Calendar.current.component(.hour, from: next!), 13)
    }

    func test_nextWorkingMoment_fromSaturday_returnsMonday() {
        let sat = date(year: 2026, month: 4, day: 25, hour: 10, minute: 0)
        let next = evaluator.nextWorkingMoment(after: sat, settings: settings)
        XCTAssertNotNil(next)
        XCTAssertEqual(Calendar.current.component(.weekday, from: next!), 2) // Monday
    }

    func test_nextWorkingMoment_fromBeforeWork_returnsStartOfWork() {
        let earlyMorning = date(year: 2026, month: 4, day: 20, hour: 7, minute: 0)
        let next = evaluator.nextWorkingMoment(after: earlyMorning, settings: settings)
        XCTAssertEqual(Calendar.current.component(.hour, from: next!), 9)
    }

    func test_pausedExpired_noLongerBlocks() {
        let now = date(year: 2026, month: 4, day: 20, hour: 10, minute: 0)
        settings.pausedUntil = now.addingTimeInterval(-60)
        XCTAssertEqual(evaluator.status(at: now, settings: settings), .working)
    }
}
