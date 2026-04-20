import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @State private var tab: Tab = .today
    @State private var showResetConfirm = false
    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    enum Tab: String, CaseIterable, Identifiable {
        case today, week
        var id: String { rawValue }
        var label: String { self == .today ? "Today" : "Week" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HopSpacing.lg) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 200)

            chartSection

            Divider()

            summarySection
        }
        .padding(HopSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(timer) { now = $0 }
        .confirmationDialog(
            "Reset all history?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { history.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your sit/stand log.")
        }
    }

    // MARK: - Chart

    @ViewBuilder private var chartSection: some View {
        switch tab {
        case .today:
            TodayChart(events: history.eventsForToday(now: now), now: now)
                .frame(height: 200)
        case .week:
            WeekChart(events: history.eventsForWeek(now: now), now: now)
                .frame(height: 240)
        }
    }

    // MARK: - Summary (compliance ring + actions)

    private var summarySection: some View {
        let week = history.eventsForWeek(now: now)
        let actionable = week.filter { $0.trigger == .notificationAction || $0.trigger == .skipped }
        let switched = actionable.filter { $0.trigger == .notificationAction }.count
        let total = actionable.count
        let pct = total == 0 ? 0 : Double(switched) / Double(total) * 100

        return HStack(alignment: .center, spacing: HopSpacing.lg) {
            ComplianceRing(percent: pct)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: HopSpacing.xs) {
                Text("This week")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(switched) of \(total) switched")
                    .font(.headline)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: HopSpacing.sm) {
                Button {
                    exportCSV()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset", systemImage: "trash")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "hop-history.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var csv = "timestamp,posture,trigger\n"
        let formatter = ISO8601DateFormatter()
        for e in history.events.sorted(by: { $0.timestamp < $1.timestamp }) {
            csv += "\(formatter.string(from: e.timestamp)),\(e.posture.rawValue),\(e.trigger.rawValue)\n"
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Compliance ring

struct ComplianceRing: View {
    let percent: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, percent / 100)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: percent)
            Text("\(Int(percent.rounded()))%")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
        .accessibilityElement()
        .accessibilityLabel("Compliance \(Int(percent.rounded())) percent")
    }
}
