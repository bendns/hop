import SwiftUI
import Charts

struct TodayChart: View {
    let segments: [PostureSegment]

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
