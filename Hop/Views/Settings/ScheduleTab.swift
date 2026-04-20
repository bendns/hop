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

            Section("Work days") {
                ForEach(Weekday.allCases) { day in
                    WorkDayRow(day: day).environmentObject(store)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Shared-hour binding

    /// Reads/writes a time field from Monday's WorkDay (canonical) and mirrors
    /// the write across every weekday so hours stay consistent.
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
}

// MARK: - Work day row

private struct WorkDayRow: View {
    @EnvironmentObject var store: SettingsStore
    let day: Weekday

    var body: some View {
        let binding = Binding<WorkDay>(
            get: { store.settings.workHoursByWeekday[day] ?? .defaultOff },
            set: { store.settings.workHoursByWeekday[day] = $0 }
        )

        HStack {
            Toggle(isOn: binding.enabled) {
                Text(day.fullName)
                    .font(.body)
            }
            .toggleStyle(.switch)

            Spacer()

            if binding.enabled.wrappedValue {
                Toggle(isOn: binding.isOfficeDay) {
                    Text("Office day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
        }
        .padding(.vertical, HopSpacing.xs)
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
