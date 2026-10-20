import Foundation

struct PostureSegment: Identifiable, Equatable {
    var id: Date { start }
    let start: Date
    let end: Date
    let posture: Posture
}

enum PostureStats {
    /// Turns events into posture segments. Each event lasts until the next event,
    /// the end of its day, or `now`, whichever comes first. Only the part that falls
    /// inside that day's work hours (minus lunch) is kept.
    static func segments(
        for events: [PostureEvent],
        until now: Date,
        settings: Settings,
        calendar: Calendar = .current
    ) -> [PostureSegment] {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        var out: [PostureSegment] = []
        for (index, event) in sorted.enumerated() {
            let dayStart = calendar.startOfDay(for: event.timestamp)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            var end = min(now, dayEnd)
            if index + 1 < sorted.count {
                end = min(end, sorted[index + 1].timestamp)
            }
            for window in workWindows(on: dayStart, settings: settings, calendar: calendar) {
                let clippedStart = max(event.timestamp, window.start)
                let clippedEnd = min(end, window.end)
                if clippedStart < clippedEnd {
                    out.append(PostureSegment(start: clippedStart, end: clippedEnd, posture: event.posture))
                }
            }
        }
        return out
    }

    /// Total sit / stand seconds, counted the same way as `segments`.
    static func totals(
        for events: [PostureEvent],
        until now: Date,
        settings: Settings,
        calendar: Calendar = .current
    ) -> (sit: TimeInterval, stand: TimeInterval) {
        segments(for: events, until: now, settings: settings, calendar: calendar)
            .reduce(into: (sit: 0, stand: 0)) { totals, segment in
                let duration = segment.end.timeIntervalSince(segment.start)
                if segment.posture == .sitting { totals.sit += duration } else { totals.stand += duration }
            }
    }

    /// The morning and afternoon work windows of the day starting at `dayStart`.
    private static func workWindows(
        on dayStart: Date,
        settings: Settings,
        calendar: Calendar
    ) -> [(start: Date, end: Date)] {
        guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: dayStart)),
              let day = settings.workHoursByWeekday[weekday],
              let start = day.start.date(on: dayStart, calendar: calendar),
              let lunchStart = day.lunchStart.date(on: dayStart, calendar: calendar),
              let lunchEnd = day.lunchEnd.date(on: dayStart, calendar: calendar),
              let end = day.end.date(on: dayStart, calendar: calendar) else { return [] }
        return [(start, lunchStart), (lunchEnd, end)]
    }
}
