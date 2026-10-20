import SwiftUI

// MARK: - Shared work hours

extension SettingsStore {
    /// Reads a time field from Monday (canonical) and writes it to every weekday,
    /// since the UI exposes a single set of work hours.
    func sharedWorkHoursBinding(_ keyPath: WritableKeyPath<WorkDay, TimeOfDay>) -> Binding<TimeOfDay> {
        Binding(
            get: {
                self.settings.workHoursByWeekday[.monday]?[keyPath: keyPath]
                    ?? TimeOfDay(hour: 9, minute: 0)
            },
            set: { newValue in
                // Build the whole map first so the store saves and publishes once.
                var map = self.settings.workHoursByWeekday
                for day in Weekday.allCases {
                    var wd = map[day] ?? .defaultOff
                    wd[keyPath: keyPath] = newValue
                    map[day] = wd
                }
                self.settings.workHoursByWeekday = map
            }
        )
    }
}

// MARK: - Time range picker

struct TimeRangePicker: View {
    @Binding var start: TimeOfDay
    @Binding var end: TimeOfDay

    var body: some View {
        HStack(spacing: HopSpacing.sm) {
            TimeField(value: $start)
            Text("–").foregroundStyle(.secondary)
            TimeField(value: $end)
        }
    }
}

struct TimeField: View {
    @Binding var value: TimeOfDay

    var body: some View {
        DatePicker(
            "",
            selection: Binding(
                get: { Self.date(from: value) },
                set: { value = Self.time(from: $0) }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.compact)
    }

    private static func date(from tod: TimeOfDay) -> Date {
        var c = DateComponents()
        c.hour = tod.hour
        c.minute = tod.minute
        return Calendar.current.date(from: c) ?? Date()
    }

    private static func time(from date: Date) -> TimeOfDay {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }
}
