import SwiftUI
import UserNotifications
import AppKit

struct MenuPopoverView: View {
    @EnvironmentObject private var scheduler: PostureScheduler
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.openWindow) private var openWindow

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    /// False while the menu bar window is closed, so the clocks below stop ticking.
    @State private var isVisible = true

    private var posture: Posture { scheduler.currentPosture }
    private var isWorking: Bool { scheduler.status == .working }
    private var isPaused: Bool { scheduler.status == .paused }

    var body: some View {
        VStack(spacing: HopSpacing.lg) {
            header
            if authStatus == .denied {
                permissionBanner
            }
            // Only the time-dependent parts re-render every second.
            TimelineView(PausableEverySecondSchedule(isPaused: !isVisible)) { context in
                hero(now: context.date)
            }
            actions
            TimelineView(PausableEverySecondSchedule(isPaused: !isVisible)) { context in
                goalCard(now: context.date)
            }
            footer
        }
        .padding(HopSpacing.lg)
        .frame(width: HopLayout.popoverWidth)
        .task { await refreshAuthStatus() }
        .onWindowVisibilityChange { isVisible = $0 }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HopWordmark()
            Spacer()
            Button {
                HopWindow.open(HopWindow.settings, using: openWindow)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Settings")
            .accessibilityLabel("Open settings")
        }
    }

    // MARK: - Hero

    private func hero(now: Date) -> some View {
        VStack(spacing: HopSpacing.md) {
            ProgressRing(progress: progress(now: now), tint: isWorking ? posture.tint : .secondary.opacity(0.4)) {
                Image(systemName: isWorking ? posture.systemImage : "moon.zzz")
                    .font(.system(size: HopLayout.stateIconSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isWorking ? posture.tint : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: posture)
            }
            .frame(width: HopLayout.ringSize, height: HopLayout.ringSize)
            .accessibilityHidden(true)

            VStack(spacing: HopSpacing.xs) {
                Text(posture.label)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .contentTransition(.numericText())
                Text(subtitle(now: now))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary(now: now))
    }

    /// Share of the current interval already elapsed; full when not counting down.
    private func progress(now: Date) -> Double {
        guard isWorking,
              let start = scheduler.transitionStartedAt,
              let end = scheduler.nextTransitionAt,
              end > start else { return 1 }
        return now.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    private func subtitle(now: Date) -> String {
        let until = scheduler.statusValidUntil
        switch scheduler.status {
        case .working:
            if let next = scheduler.nextTransitionAt {
                let remaining = next.timeIntervalSince(now)
                if remaining <= 0 { return posture == .sitting ? "Time to stand up" : "Time to sit down" }
                let verb = posture == .sitting ? "Stand up" : "Sit down"
                return "\(verb) in \(HopFormat.countdown(remaining))"
            }
            if let until { return "No more reminders before \(HopFormat.time(until))" }
            return "No reminder scheduled"
        case .onLunchBreak:
            if let until { return "Enjoy lunch · back at \(HopFormat.time(until))" }
            return "Enjoy lunch"
        case .outsideWorkHours:
            // A status change before midnight means the workday hasn't started yet.
            if let until, until != Calendar.current.startOfDay(for: until) {
                return "Your day starts at \(HopFormat.time(until))"
            }
            return "Done for today. See you tomorrow!"
        case .disabled:         return "Day off, enjoy it"
        case .officeDay:        return "Office day · no reminders"
        case .onVacation:       return "Enjoy your time off"
        case .paused:           return "Paused until tomorrow"
        case .notificationsOff: return "Reminders are turned off"
        }
    }

    private func accessibilitySummary(now: Date) -> String {
        "Currently \(posture.label.lowercased()). \(subtitle(now: now))"
    }

    // MARK: - Actions

    private var actions: some View {
        GlassEffectContainer(spacing: HopSpacing.sm) {
            VStack(spacing: HopSpacing.sm) {
                Button {
                    scheduler.markManualTransition(to: posture.toggled)
                } label: {
                    Label(
                        posture == .standing ? "I'm sitting now" : "I'm standing now",
                        systemImage: posture.toggled.systemImage
                    )
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .keyboardShortcut(.defaultAction)

                HStack(spacing: HopSpacing.sm) {
                    Group {
                        secondaryButton("Snooze", systemImage: "alarm", help: "Remind me in 10 minutes") {
                            scheduler.handleNotificationAction(.snooze, nextPosture: posture.toggled)
                        }
                        secondaryButton("Skip", systemImage: "forward", help: "Stay put for another round") {
                            scheduler.handleNotificationAction(.skip, nextPosture: posture.toggled)
                        }
                    }
                    .disabled(!isWorking)

                    secondaryButton(
                        isPaused ? "Resume" : "Pause",
                        systemImage: isPaused ? "play" : "pause",
                        help: isPaused ? "Resume reminders" : "Pause reminders until tomorrow"
                    ) {
                        isPaused ? scheduler.clearPause() : scheduler.pauseForToday()
                    }
                }
            }
        }
    }

    private func secondaryButton(
        _ title: String,
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .help(help)
    }

    // MARK: - Goal card

    private func goalCard(now: Date) -> some View {
        let totals = PostureStats.totals(
            for: history.eventsForToday(now: now),
            until: now,
            settings: settings.settings
        )
        let reached = totals.stand >= Presets.dailyStandGoal
        return VStack(alignment: .leading, spacing: HopSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Label(reached ? "Goal reached" : "Standing today", systemImage: reached ? "checkmark.seal.fill" : "figure.stand")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(reached ? Color.accentColor : .primary)
                Spacer()
                Text("\(HopFormat.duration(totals.stand)) of \(HopFormat.duration(Presets.dailyStandGoal))")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(1, totals.stand / Presets.dailyStandGoal))
                .tint(.accentColor)
            Text("Sitting \(HopFormat.duration(totals.sit))")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .hopCardStyle()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: HopSpacing.lg) {
            Button("History") { HopWindow.open(HopWindow.history, using: openWindow) }
            Button("Settings") { HopWindow.open(HopWindow.settings, using: openWindow) }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .accessibilityLabel("Quit Hop")
        }
        .buttonStyle(.link)
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    // MARK: - Permission banner

    private var permissionBanner: some View {
        HStack(spacing: HopSpacing.md) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications are off")
                    .font(.callout.weight(.medium))
                Text("Hop can't remind you to switch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Fix") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .accessibilityLabel("Open notification settings")
        }
        .hopInlineBannerStyle()
    }

    // MARK: - Helpers

    private func refreshAuthStatus() async {
        authStatus = await NotificationManager.shared.authorizationStatus()
    }
}
