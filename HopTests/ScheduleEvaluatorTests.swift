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

    func test_nextStatusChange_morning_isLunchStart() {
        let morning = date(year: 2026, month: 4, day: 20, hour: 10, minute: 0)
        XCTAssertEqual(
            evaluator.nextStatusChange(after: morning, settings: settings),
            date(year: 2026, month: 4, day: 20, hour: 12, minute: 0)
        )
    }

    func test_nextStatusChange_duringLunch_isLunchEnd() {
        let noon = date(year: 2026, month: 4, day: 20, hour: 12, minute: 30)
        XCTAssertEqual(
            evaluator.nextStatusChange(after: noon, settings: settings),
            date(year: 2026, month: 4, day: 20, hour: 13, minute: 0)
        )
    }

    func test_nextStatusChange_beforeWork_isStartOfWork() {
        let earlyMorning = date(year: 2026, month: 4, day: 20, hour: 7, minute: 0)
        XCTAssertEqual(
            evaluator.nextStatusChange(after: earlyMorning, settings: settings),
            date(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        )
    }

    func test_nextStatusChange_afterWork_isMidnight() {
        let evening = date(year: 2026, month: 4, day: 20, hour: 19, minute: 0)
        XCTAssertEqual(
            evaluator.nextStatusChange(after: evening, settings: settings),
            date(year: 2026, month: 4, day: 21, hour: 0, minute: 0)
        )
    }

    func test_nextStatusChange_withoutLunch_skipsToEndOfWork() {
        settings.workHoursByWeekday[.monday]!.lunchEnd = TimeOfDay(hour: 12, minute: 0)
        let morning = date(year: 2026, month: 4, day: 20, hour: 10, minute: 0)
        XCTAssertEqual(
            evaluator.nextStatusChange(after: morning, settings: settings),
            date(year: 2026, month: 4, day: 20, hour: 18, minute: 0)
        )
    }

    func test_nextStatusChange_includesPauseExpiry() {
        let now = date(year: 2026, month: 4, day: 20, hour: 13, minute: 0)
        settings.pausedUntil = date(year: 2026, month: 4, day: 20, hour: 15, minute: 30)
        XCTAssertEqual(evaluator.nextStatusChange(after: now, settings: settings), settings.pausedUntil)
    }

    func test_wholeDaysVacation_coversLastEvening_andSingleDay() {
        let range = DateInterval.wholeDays(
            from: date(year: 2026, month: 4, day: 20, hour: 14, minute: 37),
            through: date(year: 2026, month: 4, day: 20, hour: 14, minute: 37)
        )
        XCTAssertNotNil(range)
        settings.vacationRanges = [range!]
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 9, minute: 0), settings: settings),
            .onVacation
        )
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 17, minute: 59), settings: settings),
            .onVacation
        )
        XCTAssertEqual(
            evaluator.status(at: date(year: 2026, month: 4, day: 21, hour: 10, minute: 0), settings: settings),
            .working
        )
    }

    func test_wholeDaysVacation_rejectsReversedRange() {
        XCTAssertNil(DateInterval.wholeDays(
            from: date(year: 2026, month: 4, day: 21, hour: 0, minute: 0),
            through: date(year: 2026, month: 4, day: 20, hour: 0, minute: 0)
        ))
    }

    func test_pausedExpired_noLongerBlocks() {
        let now = date(year: 2026, month: 4, day: 20, hour: 10, minute: 0)
        settings.pausedUntil = now.addingTimeInterval(-60)
        XCTAssertEqual(evaluator.status(at: now, settings: settings), .working)
    }
}
