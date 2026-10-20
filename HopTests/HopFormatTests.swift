import XCTest
@testable import Hop

final class HopFormatTests: XCTestCase {
    func test_duration() {
        XCTAssertEqual(HopFormat.duration(0), "0m")
        XCTAssertEqual(HopFormat.duration(12 * 60 + 59), "12m")
        XCTAssertEqual(HopFormat.duration(3 * 3600), "3h")
        XCTAssertEqual(HopFormat.duration(3600 + 5 * 60), "1h 05m")
        XCTAssertEqual(HopFormat.duration(-30), "0m")
    }

    func test_countdown() {
        XCTAssertEqual(HopFormat.countdown(0), "00:00")
        XCTAssertEqual(HopFormat.countdown(29 * 60 + 58), "29:58")
        XCTAssertEqual(HopFormat.countdown(3600 + 2 * 60 + 3), "1:02:03")
    }

    func test_weekChart_putsEachDayInItsOwnBucket() {
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 21; c.hour = 15
        let now = Calendar.current.date(from: c)! // Tuesday
        c.day = 20; c.hour = 10
        let monday = Calendar.current.date(from: c)!
        let days = WeekChart.days(
            for: [PostureEvent(timestamp: monday, posture: .standing, trigger: .manual)],
            now: now,
            settings: .default
        )
        XCTAssertEqual(days.count, 7)
        let mondayStat = days.first { Calendar.current.isDate($0.id, inSameDayAs: monday) }
        XCTAssertEqual(mondayStat?.standingHours ?? 0, 7, accuracy: 0.01) // 10–12 and 13–18
    }
}
