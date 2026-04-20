import SwiftUI
import Charts

struct WeekChart: View {
    let events: [PostureEvent]
    let now: Date

    struct DayStat: Identifiable {
        let id: Date
        let standingHours: Double
        let sittingHours: Double
    }

    private static let targetHours: Double = 3

    var data: [DayStat] {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        var days: [DayStat] = []
        for offset in 0..<7 {
            let dayStart = cal.date(byAdding: .day, value: offset, to: weekStart)!
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let dayEvents = events.filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
            let upperBound = min(now, dayEnd)
            let totals = MenuPopoverView.totals(for: dayEvents, now: upperBound, current: .sitting)
            days.append(DayStat(
                id: dayStart,
                standingHours: totals.stand / 3600,
                sittingHours: totals.sit / 3600
            ))
        }
        return days
    }

    var body: some View {
        Chart(data) { day in
            BarMark(
                x: .value("Day", day.id, unit: .day),
                y: .value("Sitting", day.sittingHours)
            )
            .foregroundStyle(Color.secondary)
            .cornerRadius(3)

            BarMark(
                x: .value("Day", day.id, unit: .day),
                y: .value("Standing", day.standingHours)
            )
            .foregroundStyle(Color.accentColor)
            .cornerRadius(3)

            RuleMark(y: .value("Target", Self.targetHours))
                .foregroundStyle(.tertiary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel().font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
