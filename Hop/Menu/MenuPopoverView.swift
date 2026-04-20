import SwiftUI
import UserNotifications
import AppKit

struct MenuPopoverView: View {
    @EnvironmentObject private var scheduler: PostureScheduler
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.openWindow) private var openWindow

    @State private var tick: Date = Date()
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var cardPulse: CGFloat = 1.0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isStanding: Bool { scheduler.currentPosture == .standing }
    private var isPaused: Bool { settings.settings.pausedUntil != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: HopSpacing.lg) {
            if authStatus == .denied {
                permissionBanner
            }
            header
            stateCard
            primaryAction
            secondaryActions
            statsStrip
            footer
        }
        .padding(HopSpacing.lg)
        .frame(width: HopLayout.popoverWidth)
        .onReceive(timer) { tick = $0 }
        .task { await refreshAuthStatus() }
        .onChange(of: scheduler.currentPosture) { _ in pulse() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HopWordmark()
            Spacer()
            Button {
                openWindow(id: "settings")
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")
        }
    }

    // MARK: - State card

    private var stateCard: some View {
        VStack(spacing: HopSpacing.sm) {
            Image(systemName: postureIconName)
                .font(.system(size: HopLayout.stateIconSize, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isStanding ? Color.accentColor : Color.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: postureIconName)
                .accessibilityHidden(true)

            VStack(spacing: HopSpacing.xs) {
                Text(isStanding ? "Standing" : "Sitting")
                    .font(.title2.weight(.semibold))
                countdownLine
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: HopLayout.stateCardHeight)
        .padding(.horizontal, HopSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HopRadius.container, style: .continuous)
                .fill(.quaternary)
        )
        .scaleEffect(cardPulse)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stateCardAccessibility)
    }

    private var countdownLine: some View {
        Group {
            if scheduler.status != .working {
                Text(statusLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            } else if let next = scheduler.nextTransitionAt {
                let remaining = max(0, next.timeIntervalSince(tick))
                Text("in \(format(remaining))")
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var postureIconName: String {
        isStanding ? "figure.stand" : "figure.seated.side"
    }

    private var statusLabel: String {
        switch scheduler.status {
        case .working:            return ""
        case .onLunchBreak:       return "Lunch break"
        case .outsideWorkHours:   return "Outside work hours"
        case .weekend, .disabled: return "Day off"
        case .officeDay:          return "Office day"
        case .onVacation:         return "On vacation"
        case .paused:             return "Paused for today"
        case .notificationsOff:   return "Notifications off"
        }
    }

    private var stateCardAccessibility: String {
        let posture = isStanding ? "standing" : "sitting"
        if scheduler.status == .working, let next = scheduler.nextTransitionAt {
            let remaining = max(0, Int(next.timeIntervalSince(tick)) / 60)
            return "Currently \(posture). Next switch in \(remaining) minutes."
        }
        return "Currently \(posture). \(statusLabel)"
    }

    // MARK: - Primary action

    private var primaryAction: some View {
        Button {
            scheduler.markManualTransition(to: scheduler.currentPosture.toggled)
        } label: {
            HStack(spacing: HopSpacing.sm) {
                Image(systemName: isStanding ? "figure.seated.side" : "figure.stand")
                Text(isStanding ? "I'm sitting now" : "I'm standing now")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .accessibilityLabel(isStanding ? "Mark sitting" : "Mark standing")
    }

    // MARK: - Secondary actions

    private var secondaryActions: some View {
        HStack(spacing: HopSpacing.sm) {
            secondaryButton(
                label: "Snooze 10m",
                systemImage: "alarm",
                action: {
                    scheduler.handleNotificationAction(.snooze, nextPosture: scheduler.currentPosture.toggled)
                }
            )
            secondaryButton(
                label: "Skip",
                systemImage: "forward",
                action: {
                    scheduler.handleNotificationAction(.skip, nextPosture: scheduler.currentPosture.toggled)
                }
            )
            secondaryButton(
                label: isPaused ? "Resume" : "Pause today",
                systemImage: isPaused ? "play.circle" : "pause.circle",
                action: {
                    isPaused ? scheduler.clearPause() : scheduler.pauseForToday()
                }
            )
        }
    }

    private func secondaryButton(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: HopSpacing.xs) {
                Image(systemName: systemImage).font(.body)
                Text(label).font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .accessibilityLabel(label)
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        let events = history.eventsForToday(now: tick)
        let totals = MenuPopoverView.totals(for: events, now: tick, current: scheduler.currentPosture)
        return HStack(spacing: HopSpacing.xl) {
            statCell(systemImage: "figure.stand", label: "Standing", value: format(totals.stand))
            Divider().frame(height: 28)
            statCell(systemImage: "figure.seated.side", label: "Sitting", value: format(totals.sit))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statCell(systemImage: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: HopSpacing.xs) {
            Label(label, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: HopSpacing.lg) {
            Button("History") { openWindow(id: "history") }
                .accessibilityLabel("Open history")
            Button("Settings") { openWindow(id: "settings") }
                .accessibilityLabel("Open settings")
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .accessibilityLabel("Quit Hop")
        }
        .buttonStyle(.link)
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Permission banner

    private var permissionBanner: some View {
        HStack(spacing: HopSpacing.md) {
            Image(systemName: "bell.slash")
                .foregroundStyle(Color.accentColor)
                .font(.body)
            VStack(alignment: .leading, spacing: HopSpacing.xs) {
                Text("Notifications are off")
                    .font(.caption.weight(.medium))
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            Spacer()
        }
        .hopInlineBannerStyle()
    }

    // MARK: - Helpers

    private func refreshAuthStatus() async {
        authStatus = await NotificationManager.shared.authorizationStatus()
    }

    private func pulse() {
        withAnimation(.easeInOut(duration: 0.12)) { cardPulse = 1.04 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.12)) { cardPulse = 1.0 }
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%dh %02dm", h, m) : String(format: "%02d:%02d", m, s)
    }

    /// Collapses events into total sit / stand seconds up to `now`.
    static func totals(for events: [PostureEvent], now: Date, current: Posture) -> (sit: TimeInterval, stand: TimeInterval) {
        var sit: TimeInterval = 0
        var stand: TimeInterval = 0
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        for (i, e) in sorted.enumerated() {
            let end = i + 1 < sorted.count ? sorted[i + 1].timestamp : now
            let delta = max(0, end.timeIntervalSince(e.timestamp))
            if e.posture == .sitting { sit += delta } else { stand += delta }
        }
        return (sit, stand)
    }
}
