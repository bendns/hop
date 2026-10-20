import SwiftUI

struct ScheduleTab: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section("Work hours") {
                LabeledContent("Hours") {
                    TimeRangePicker(
                        start: store.sharedWorkHoursBinding(\.start),
                        end: store.sharedWorkHoursBinding(\.end)
                    )
                }
                LabeledContent("Lunch") {
                    TimeRangePicker(
                        start: store.sharedWorkHoursBinding(\.lunchStart),
                        end: store.sharedWorkHoursBinding(\.lunchEnd)
                    )
                }
                Text("Applied to every working day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let warning = hoursWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
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

    private var hoursWarning: String? {
        guard let day = store.settings.workHoursByWeekday[.monday] else { return nil }
        if day.end <= day.start { return "Work hours end before they start." }
        if day.lunchEnd < day.lunchStart || day.lunchStart < day.start || day.lunchEnd > day.end {
            return "Lunch should fall within work hours."
        }
        return nil
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
