import XCTest
@testable import Hop

final class PostureStatsTests: XCTestCase {
    private let settings = Settings.default // Mon–Fri 9–18, lunch 12–13

    private func at(day: Int = 20, hour: Int, minute: Int = 0) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    private func event(_ date: Date, _ posture: Posture) -> PostureEvent {
        PostureEvent(timestamp: date, posture: posture, trigger: .manual)
    }

    func test_totals_stopAtEndOfWorkDay() {
        // Last switch at 17:00, checked late in the evening: only 17–18 counts.
        let totals = PostureStats.totals(
            for: [event(at(hour: 17), .sitting)],
            until: at(hour: 23),
            settings: settings
        )
        XCTAssertEqual(totals.sit, 3600, accuracy: 1)
        XCTAssertEqual(totals.stand, 0)
    }

    func test_totals_excludeLunch() {
        let totals = PostureStats.totals(
            for: [event(at(hour: 11), .standing), event(at(hour: 14), .sitting)],
            until: at(hour: 15),
            settings: settings
        )
        XCTAssertEqual(totals.stand, 2 * 3600, accuracy: 1) // 11–12 and 13–14
        XCTAssertEqual(totals.sit, 3600, accuracy: 1)       // 14–15
    }

    func test_totals_ignoreTimeBeforeWork() {
        let totals = PostureStats.totals(
            for: [event(at(hour: 7), .sitting)],
            until: at(hour: 10),
            settings: settings
        )
        XCTAssertEqual(totals.sit, 3600, accuracy: 1)
    }

    func test_segments_neverCrossMidnight() {
        // A Monday event must not count Tuesday's work hours.
        let segments = PostureStats.segments(
            for: [event(at(hour: 17), .sitting)],
            until: at(day: 21, hour: 12),
            settings: settings
        )
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.end, at(hour: 18))
    }

    func test_segments_haveUniqueIds() {
        let segments = PostureStats.segments(
            for: [event(at(hour: 9), .sitting), event(at(hour: 9), .standing), event(at(hour: 10), .sitting)],
            until: at(hour: 11),
            settings: settings
        )
        XCTAssertEqual(Set(segments.map(\.id)).count, segments.count)
    }
}
