import Foundation

enum ScheduleStatus: Equatable {
    case working
    case outsideWorkHours
    case onLunchBreak
    case officeDay
    case onVacation
    case paused
    case disabled            // day toggled off
    case notificationsOff    // global toggle
}

struct ScheduleEvaluator {
    let calendar: Calendar

    init(calendar: Calendar = .current) { self.calendar = calendar }

    func status(at date: Date, settings: Settings) -> ScheduleStatus {
        if !settings.notificationsEnabled { return .notificationsOff }
        if let until = settings.pausedUntil, date < until { return .paused }
        if settings.vacationRanges.contains(where: { $0.contains(date) }) { return .onVacation }

        let weekday = Weekday(rawValue: calendar.component(.weekday, from: date))!
        guard let day = settings.workHoursByWeekday[weekday] else { return .disabled }
        if !day.enabled { return .disabled }
        if day.isOfficeDay { return .officeDay }

        let tod = TimeOfDay(
            hour: calendar.component(.hour, from: date),
            minute: calendar.component(.minute, from: date)
        )
        if tod < day.start || tod >= day.end { return .outsideWorkHours }
        if tod >= day.lunchStart && tod < day.lunchEnd { return .onLunchBreak }
        return .working
    }

    /// Returns the first moment after `date` at which `status` differs from its value
    /// at `date`. Falls back to the next midnight, so callers re-evaluate at least daily.
    func nextStatusChange(after date: Date, settings: Settings) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let midnight = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        var candidates: [Date] = []
        if let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)),
           let day = settings.workHoursByWeekday[weekday] {
            for time in [day.start, day.lunchStart, day.lunchEnd, day.end] {
                if let moment = time.date(on: dayStart, calendar: calendar) {
                    candidates.append(moment)
                }
            }
        }
        if let until = settings.pausedUntil {
            candidates.append(until)
        }
        for range in settings.vacationRanges {
            candidates += [range.start, range.end]
        }

        let current = status(at: date, settings: settings)
        return candidates
            .filter { $0 > date && $0 < midnight }
            .sorted()
            .first { status(at: $0, settings: settings) != current } ?? midnight
    }
}
