import SwiftUI
import Charts

struct WeekChart: View {
    let events: [PostureEvent]
    let now: Date
    let settings: Settings

    struct DayStat: Identifiable {
        let id: Date
        let standingHours: Double
        let sittingHours: Double
    }

    private static let targetHours: Double = 3

    var data: [DayStat] {
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
