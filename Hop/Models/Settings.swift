import Foundation

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { rawValue }
    var shortName: String {
        ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][rawValue]
    }
    var fullName: String {
        ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][rawValue]
    }
    static var workweek: [Weekday] { [.monday, .tuesday, .wednesday, .thursday, .friday] }
}

/// Minute-of-day (0..1440).
struct TimeOfDay: Codable, Equatable, Comparable {
    var minutes: Int
    init(hour: Int, minute: Int) { self.minutes = hour * 60 + minute }
    init(minutes: Int) { self.minutes = minutes }
    var hour: Int { minutes / 60 }
    var minute: Int { minutes % 60 }
    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.minutes < rhs.minutes }

    /// This time of day on the same calendar day as `day`.
    func date(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}

struct WorkDay: Codable, Equatable {
    var enabled: Bool
    var start: TimeOfDay
    var end: TimeOfDay
    var lunchStart: TimeOfDay
    var lunchEnd: TimeOfDay
    var isOfficeDay: Bool

    static let defaultWork = WorkDay(
        enabled: true,
        start: TimeOfDay(hour: 9, minute: 0),
        end: TimeOfDay(hour: 18, minute: 0),
        lunchStart: TimeOfDay(hour: 12, minute: 0),
        lunchEnd: TimeOfDay(hour: 13, minute: 0),
        isOfficeDay: false
    )
    static let defaultOff = WorkDay(
        enabled: false,
        start: TimeOfDay(hour: 9, minute: 0),
        end: TimeOfDay(hour: 18, minute: 0),
        lunchStart: TimeOfDay(hour: 12, minute: 0),
        lunchEnd: TimeOfDay(hour: 13, minute: 0),
        isOfficeDay: false
    )
}

struct Settings: Codable, Equatable {
    var mode: Mode
    var customStandMinutes: Int
    var customSitMinutes: Int
    var workHoursByWeekday: [Weekday: WorkDay]
    var vacationRanges: [DateInterval]
    var pausedUntil: Date?
    var notificationsEnabled: Bool

    static let `default`: Settings = {
        var map: [Weekday: WorkDay] = [:]
        for day in Weekday.allCases {
            map[day] = Weekday.workweek.contains(day) ? .defaultWork : .defaultOff
        }
        return Settings(
            mode: .science,
            customStandMinutes: 30,
            customSitMinutes: 30,
            workHoursByWeekday: map,
            vacationRanges: [],
            pausedUntil: nil,
            notificationsEnabled: true
        )
    }()
}

extension DateInterval {
    /// Covers every calendar day from `first` through `last`, both inclusive.
    /// Returns nil when `last` is before `first`.
    static func wholeDays(from first: Date, through last: Date, calendar: Calendar = .current) -> DateInterval? {
        let start = calendar.startOfDay(for: first)
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)),
              end > start else { return nil }
        return DateInterval(start: start, end: end)
    }
}
