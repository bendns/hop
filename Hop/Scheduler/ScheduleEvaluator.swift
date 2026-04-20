import Foundation

enum ScheduleStatus: Equatable {
    case working
    case outsideWorkHours
    case onLunchBreak
    case weekend
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

    func isWorking(at date: Date, settings: Settings) -> Bool {
        status(at: date, settings: settings) == .working
    }

    /// Returns the next `Date` where status becomes `.working`, searching forward
    /// up to 14 days at minute granularity. Returns nil if none found.
    func nextWorkingMoment(after date: Date, settings: Settings) -> Date? {
        var cursor = date
        let horizon = calendar.date(byAdding: .day, value: 14, to: date)!
        while cursor < horizon {
            if isWorking(at: cursor, settings: settings) { return cursor }
            cursor = cursor.addingTimeInterval(60)
        }
        return nil
    }
}
