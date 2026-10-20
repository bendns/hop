import SwiftUI
import AppKit

/// First-launch flow: introduce Hop, pick a rhythm, then ask for notifications
/// in context instead of at launch.
struct WelcomeView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .hello

    enum Step: Int, CaseIterable {
        case hello, rhythm, notifications
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .hello:         hello
                case .rhythm:        rhythm
                case .notifications: notifications
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(reduceMotion ? .opacity : .push(from: .trailing))

            pageDots
                .padding(.bottom, HopSpacing.lg)
        }
        .frame(width: 520, height: 600)
        .onAppear { NSApp.activate() }
    }

    // MARK: - Steps

    private var hello: some View {
        VStack(spacing: HopSpacing.xl) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
            VStack(spacing: HopSpacing.sm) {
                Text("Welcome to Hop!")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("A gentle nudge to switch between sitting and standing through your workday.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            VStack(alignment: .leading, spacing: HopSpacing.md) {
                feature("bell.badge", "One quiet reminder at a time", "Answer it right from the notification.")
                feature("calendar", "Fits your schedule", "Respects work hours, lunch, office days and vacations.")
                feature("lock", "Stays on your Mac", "No account, no tracking, no network.")
            }
            .frame(maxWidth: 380)
            Spacer()
            primaryButton("Get started") { go(to: .rhythm) }
        }
        .padding(.horizontal, HopSpacing.xxl)
    }

    private var rhythm: some View {
        VStack(alignment: .leading, spacing: HopSpacing.lg) {
            header("Find your rhythm", "You can change this anytime in Settings.")
            ModePicker(selection: Binding(
                get: { store.settings.mode == .custom ? nil : store.settings.mode },
                set: { if let mode = $0 { store.settings.mode = mode } }
            ))
            VStack(spacing: HopSpacing.sm) {
                LabeledContent("Work hours") {
                    TimeRangePicker(
                        start: store.sharedWorkHoursBinding(\.start),
                        end: store.sharedWorkHoursBinding(\.end)
                    )
                }
                Divider()
                LabeledContent("Lunch") {
                    TimeRangePicker(
                        start: store.sharedWorkHoursBinding(\.lunchStart),
                        end: store.sharedWorkHoursBinding(\.lunchEnd)
                    )
                }
            }
            .hopCardStyle()
            Spacer()
            HStack {
                Button("Back") { go(to: .hello) }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                Spacer()
                primaryButton("Continue") { go(to: .notifications) }
            }
        }
        .padding(.horizontal, HopSpacing.xxl)
        .padding(.top, HopSpacing.xxl)
    }

    private var notifications: some View {
        VStack(spacing: HopSpacing.xl) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.wiggle, options: .nonRepeating)
                .accessibilityHidden(true)
            VStack(spacing: HopSpacing.sm) {
                Text("Let Hop nudge you")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("Hop needs notifications to tell you when it's time to switch. You can reply with Switched, Snooze or Skip without leaving what you're doing.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            Spacer()
            VStack(spacing: HopSpacing.sm) {
                primaryButton("Allow notifications") {
                    Task {
                        _ = await NotificationManager.shared.requestAuthorization()
                        finish()
                    }
                }
                Button("Not now") { finish() }
                    .buttonStyle(.link)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, HopSpacing.xxl)
    }

    // MARK: - Pieces

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: HopSpacing.xs) {
            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private func feature(_ systemImage: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: HopSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(minWidth: 160)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .keyboardShortcut(.defaultAction)
    }

    private var pageDots: some View {
        HStack(spacing: HopSpacing.sm) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: item == step ? 18 : 6, height: 6)
            }
        }
        .animation(.snappy, value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    // MARK: - Navigation

    private func go(to next: Step) {
        withAnimation(.smooth) { step = next }
    }

    private func finish() {
        Onboarding.complete()
        dismissWindow(id: HopWindow.welcome)
    }
}
