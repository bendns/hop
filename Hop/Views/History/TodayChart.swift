import SwiftUI
import Charts

struct TodayChart: View {
    let segments: [PostureSegment]

    @State private var selectedTime: Date?

    var body: some View {
        if segments.isEmpty {
            ContentUnavailableView(
                "No activity yet today",
                systemImage: "clock",
                description: Text("Time counts once your workday starts.")
            )
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(segments) { segment in
                BarMark(
                    xStart: .value("Start", segment.start),
                    xEnd: .value("End", segment.end),
                    y: .value("Posture", segment.posture.label)
                )
                .foregroundStyle(by: .value("Posture", segment.posture.label))
                .cornerRadius(6)
                .opacity(selectedSegment == nil || selectedSegment == segment ? 1 : 0.4)
            }

            if let selected = selectedSegment {
                RuleMark(x: .value("Time", selectedTime ?? selected.start))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        tooltip(for: selected)
                    }
            }
        }
        .chartForegroundStyleScale([
            Posture.standing.label: Color.accentColor,
            Posture.sitting.label: Color.secondary.opacity(0.45),
        ])
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedTime)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel(format: .dateTime.hour().minute())
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.caption)
            }
        }
    }

    private var selectedSegment: PostureSegment? {
        guard let selectedTime else { return nil }
        return segments.first { $0.start <= selectedTime && selectedTime < $0.end }
    }

    private func tooltip(for segment: PostureSegment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(segment.posture.label, systemImage: segment.posture.systemImage)
                .font(.caption.weight(.semibold))
            Text("\(HopFormat.time(segment.start)) – \(HopFormat.time(segment.end))")
                .font(.caption)
            Text(HopFormat.duration(segment.end.timeIntervalSince(segment.start)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
        .padding(HopSpacing.sm)
        .background(.regularMaterial, in: .rect(cornerRadius: HopRadius.small))
    }
}
