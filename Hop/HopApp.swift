import SwiftUI

@main
struct HopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var scheduler = PostureScheduler.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var history = HistoryStore.shared

    init() {
        // Both must run before any store loads or the scheduler persists posture.
        // Unit tests launch the app as their host; they must not consume the
        // one-time migration of the developer's real data.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            LegacyDataMigration.runIfNeeded()
        }
        _ = Onboarding.isNeeded
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView()
                .environmentObject(scheduler)
                .environmentObject(settings)
                .environmentObject(history)
        } label: {
            Image(systemName: iconName(for: scheduler.status, posture: scheduler.currentPosture))
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: scheduler.currentPosture)
                .animation(.easeInOut(duration: 0.2), value: scheduler.status)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to Hop!", id: HopWindow.welcome) {
            WelcomeView()
                .environmentObject(settings)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(Onboarding.isNeeded ? .presented : .suppressed)
        .restorationBehavior(.disabled)

        Window("Settings", id: HopWindow.settings) {
            SettingsView()
                .environmentObject(settings)
        }
        .defaultSize(width: 540, height: 440)

        Window("History", id: HopWindow.history) {
            HistoryView()
                .environmentObject(history)
                .environmentObject(settings)
        }
        .defaultSize(width: 720, height: 560)
    }

    private func iconName(for status: ScheduleStatus, posture: Posture) -> String {
        switch status {
        case .working:
            return posture == .standing ? "figure.stand" : "figure.seated.side"
        default:
            return "moon.zzz"
        }
    }
}
