import Foundation

/// Tracks whether the first-launch welcome flow has been completed.
@MainActor
enum Onboarding {
    private static let key = "hop.onboarded.v1"
    /// Written by PostureScheduler on first run; its presence means Hop ran before
    /// this flow existed, so the user should not see it.
    private static let existingUserKey = "hop.lastPostureDate.v1"

    /// Evaluated once at launch, before the scheduler writes anything.
    static let isNeeded: Bool = {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: key), defaults.object(forKey: existingUserKey) != nil {
            defaults.set(true, forKey: key)
        }
        return !defaults.bool(forKey: key)
    }()

    static func complete() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
