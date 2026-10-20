import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var settings: SettingsStore
    @State private var tab: Tab = .today
    @State private var showResetConfirm = false

    enum Tab: String, CaseIterable, Identifiable {
        case today, week
        var id: String { rawValue }
        var label: String { self == .today ? "Today" : "This Week" }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .frame(minWidth: 640, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Period", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Export CSV", systemImage: "square.and.arrow.up", action: exportCSV)
                    .help("Export your history as CSV")
                Button("Reset History", systemImage: "trash", role: .destructive) {
                    showResetConfirm = true
                }
                .help("Delete all history")
            }
        }
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

    private func content(now: Date) -> some View {
        let weekEvents = history.eventsForWeek(now: now)
        let todaySegments = PostureStats.segments(
            for: history.eventsForToday(now: now),
            until: now,
            settings: settings.settings
        )
        let weekDays = WeekChart.days(for: weekEvents, now: now, settings: settings.settings)

        return ScrollView {
            VStack(alignment: .leading, spacing: HopSpacing.lg) {
                summaryCards(todaySegments: todaySegments, weekDays: weekDays, weekEvents: weekEvents)

                VStack(alignment: .leading, spacing: HopSpacing.md) {
                    Text(tab == .today ? "Your day" : "Your week")
                        .font(.headline)
                    Group {
                        switch tab {
                        case .today: TodayChart(segments: todaySegments)
                        case .week:  WeekChart(days: weekDays)
                        }
                    }
                    .frame(height: 260)
                }
                .hopCardStyle(padding: HopSpacing.lg)
            }
            .padding(HopSpacing.xl)
        }
    }

    // MARK: - Summary cards

    private func summaryCards(
        todaySegments: [PostureSegment],
        weekDays: [WeekChart.DayStat],
        weekEvents: [PostureEvent]
    ) -> some View {
        let standToday = todaySegments
            .filter { $0.posture == .standing }
            .reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }

        let activeDays = weekDays.filter { $0.standingHours + $0.sittingHours > 0 }
        let averageStand = activeDays.isEmpty
            ? 0
            : activeDays.reduce(0) { $0 + $1.standingHours } / Double(activeDays.count) * 3600

        let answered = weekEvents.filter { $0.trigger == .notificationAction || $0.trigger == .skipped }
        let switched = answered.filter { $0.trigger == .notificationAction }.count
        let switchRate = answered.isEmpty ? 0 : Double(switched) / Double(answered.count)

        return HStack(spacing: HopSpacing.md) {
            summaryCard(
                title: "Standing today",
                value: HopFormat.duration(standToday),
                detail: "of \(HopFormat.duration(Presets.dailyStandGoal)) goal",
                progress: standToday / Presets.dailyStandGoal,
                systemImage: "figure.stand"
            )
            summaryCard(
                title: "Daily average",
                value: HopFormat.duration(averageStand),
                detail: "standing this week",
                progress: averageStand / Presets.dailyStandGoal,
                systemImage: "chart.bar.fill"
            )
            summaryCard(
                title: "Switch rate",
                value: "\(Int((switchRate * 100).rounded()))%",
                detail: answered.isEmpty ? "no reminders yet" : "\(switched) of \(answered.count) reminders",
                progress: switchRate,
                systemImage: "arrow.left.arrow.right"
            )
        }
    }

    private func summaryCard(
        title: String,
        value: String,
        detail: String,
        progress: Double,
        systemImage: String
    ) -> some View {
        HStack(spacing: HopSpacing.md) {
            ProgressRing(progress: progress, tint: .accentColor, lineWidth: 5) {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .hopCardStyle()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Export

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
