import SwiftUI

struct ScheduleTab: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section("Work hours") {
                LabeledContent("Hours") {
                    TimeRangePicker(
                        start: sharedBinding(\.start),
                        end: sharedBinding(\.end)
                    )
                }
                LabeledContent("Lunch") {
                    TimeRangePicker(
                        start: sharedBinding(\.lunchStart),
                        end: sharedBinding(\.lunchEnd)
                    )
                }
                Text("Applied to every working day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(Weekday.allCases) { day in
                    LabeledContent(day.fullName) {
                        Picker("", selection: dayModeBinding(for: day)) {
                            ForEach(DayMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(minWidth: 200)
                    }
                }
            } header: {
                Text("Work days")
            } footer: {
                Text("**Off** — no reminders · **Home** — reminders fire · **Office** — no reminders (you're away from your desk)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Bindings

    private func sharedBinding(_ keyPath: WritableKeyPath<WorkDay, TimeOfDay>) -> Binding<TimeOfDay> {
        Binding(
            get: {
                store.settings.workHoursByWeekday[.monday]?[keyPath: keyPath]
                    ?? TimeOfDay(hour: 9, minute: 0)
            },
            set: { newValue in
                for day in Weekday.allCases {
                    var wd = store.settings.workHoursByWeekday[day] ?? .defaultOff
                    wd[keyPath: keyPath] = newValue
                    store.settings.workHoursByWeekday[day] = wd
                }
            }
        )
    }

    private func dayModeBinding(for day: Weekday) -> Binding<DayMode> {
        Binding(
            get: {
                let wd = store.settings.workHoursByWeekday[day] ?? .defaultOff
                if !wd.enabled { return .off }
                return wd.isOfficeDay ? .office : .home
            },
            set: { newMode in
                var wd = store.settings.workHoursByWeekday[day] ?? .defaultOff
                switch newMode {
                case .off:
                    wd.enabled = false
                    wd.isOfficeDay = false
                case .home:
                    wd.enabled = true
                    wd.isOfficeDay = false
                case .office:
                    wd.enabled = true
                    wd.isOfficeDay = true
                }
                store.settings.workHoursByWeekday[day] = wd
            }
        )
    }
}

// MARK: - Day mode

private enum DayMode: String, CaseIterable, Identifiable, Hashable {
    case off, home, office
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off:    return "Off"
        case .home:   return "Home"
        case .office: return "Office"
        }
    }
}

// MARK: - Time range picker

private struct TimeRangePicker: View {
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

private struct TimeField: View {
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
