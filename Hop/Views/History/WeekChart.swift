import SwiftUI
import Charts

struct WeekChart: View {
    let days: [DayStat]

    struct DayStat: Identifiable {
        let id: Date
        let standingHours: Double
        let sittingHours: Double
    }

    @State private var selectedDay: Date?

    private static let goalHours = Presets.dailyStandGoal / 3600

    /// Per-day totals for the week containing `now`.
    static func days(for events: [PostureEvent], now: Date, settings: Settings) -> [DayStat] {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        // Segments never cross midnight, so each one belongs to the day it starts on.
        let byDay = Dictionary(
            grouping: PostureStats.segments(for: events, until: now, settings: settings, calendar: cal),
            by: { cal.startOfDay(for: $0.start) }
        )
        return (0..<7).map { offset in
            let dayStart = cal.date(byAdding: .day, value: offset, to: weekStart)!
            var stand: TimeInterval = 0
            var sit: TimeInterval = 0
            for segment in byDay[dayStart] ?? [] {
                let duration = segment.end.timeIntervalSince(segment.start)
                if segment.posture == .standing { stand += duration } else { sit += duration }
            }
            return DayStat(id: dayStart, standingHours: stand / 3600, sittingHours: sit / 3600)
        }
    }

    var body: some View {
        if days.allSatisfy({ $0.standingHours + $0.sittingHours == 0 }) {
            ContentUnavailableView(
                "No activity this week",
                systemImage: "chart.bar",
                description: Text("Your sit and stand time will show up here.")
            )
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(days) { day in
                // Standing first, so it sits at the bottom of the stack and
                // lines up with the goal rule.
                BarMark(
                    x: .value("Day", day.id, unit: .day),
                    y: .value("Hours", day.standingHours)
                )
                .foregroundStyle(by: .value("Posture", Posture.standing.label))
                BarMark(
                    x: .value("Day", day.id, unit: .day),
                    y: .value("Hours", day.sittingHours)
                )
                .foregroundStyle(by: .value("Posture", Posture.sitting.label))
            }
            .cornerRadius(4)
            .opacity(selectedDay == nil ? 1 : 0.5)

            if let selected = selectedDayStat {
                RuleMark(x: .value("Day", selected.id, unit: .day))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        tooltip(for: selected)
                    }
            }

            RuleMark(y: .value("Goal", Self.goalHours))
                .foregroundStyle(Color.accentColor.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Goal \(Int(Self.goalHours))h")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
        }
        .chartForegroundStyleScale([
            Posture.standing.label: Color.accentColor,
            Posture.sitting.label: Color.secondary.opacity(0.45),
        ])
        .chartLegend(position: .top, alignment: .leading)
        .chartXSelection(value: $selectedDay)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let hours = value.as(Double.self) { Text("\(Int(hours))h") }
                }
                .font(.caption)
            }
        }
    }

    private var selectedDayStat: DayStat? {
        guard let selectedDay else { return nil }
        return days.first { Calendar.current.isDate($0.id, inSameDayAs: selectedDay) }
    }

    private func tooltip(for day: DayStat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.id.formatted(.dateTime.weekday(.wide)))
                .font(.caption.weight(.semibold))
            Text("Standing \(HopFormat.duration(day.standingHours * 3600))")
                .font(.caption)
            Text("Sitting \(HopFormat.duration(day.sittingHours * 3600))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
        .padding(HopSpacing.sm)
        .background(.regularMaterial, in: .rect(cornerRadius: HopRadius.small))
    }
}
