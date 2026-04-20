import SwiftUI
import Charts

struct TodayChart: View {
    let events: [PostureEvent]
    let now: Date

    struct Segment: Identifiable {
        let id = UUID()
        let start: Date
        let end: Date
        let posture: Posture
    }

    var segments: [Segment] {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        var out: [Segment] = []
        for (i, e) in sorted.enumerated() {
            let end = i + 1 < sorted.count ? sorted[i + 1].timestamp : now
            out.append(Segment(start: e.timestamp, end: end, posture: e.posture))
        }
        return out
    }

    var body: some View {
        if segments.isEmpty {
            emptyState
        } else {
            Chart(segments) { s in
                BarMark(
                    xStart: .value("Start", s.start),
                    xEnd: .value("End", s.end),
                    y: .value("Posture", s.posture == .standing ? "Standing" : "Sitting")
                )
                .foregroundStyle(s.posture == .standing ? Color.accentColor : Color.secondary)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel().font(.caption).foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: HopSpacing.sm) {
            Image(systemName: "clock")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No activity yet today.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
