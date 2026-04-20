import Foundation
import UserNotifications

enum NotificationAction: String {
    case switched = "hop.action.switched"
    case snooze = "hop.action.snooze"
    case skip = "hop.action.skip"
}

enum NotificationCategory: String {
    case postureSwitch = "hop.category.postureSwitch"
}

protocol NotificationScheduling: Sendable {
    func schedule(nextPosture: Posture, fireAt: Date)
    func cancelAll()
}

final class NotificationManager: NotificationScheduling, @unchecked Sendable {
    nonisolated(unsafe) static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "hop.notification."

    func registerCategories() {
        let switched = UNNotificationAction(
            identifier: NotificationAction.switched.rawValue,
            title: "Switched",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Snooze 10 min",
            options: []
        )
        let skip = UNNotificationAction(
            identifier: NotificationAction.skip.rawValue,
            title: "Skip this one",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: NotificationCategory.postureSwitch.rawValue,
            actions: [switched, snooze, skip],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Schedules exactly one posture-switch notification at `fireAt`.
    /// Replaces any previously-scheduled notification.
    func schedule(nextPosture: Posture, fireAt: Date) {
        cancelAll()
        let content = UNMutableNotificationContent()
        switch nextPosture {
        case .standing:
            content.title = "Time to stand up"
            content.body = "You've been sitting for a while."
        case .sitting:
            content.title = "Time to sit down"
            content.body = "Nice standing streak. Time for a break."
        }
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.postureSwitch.rawValue
        content.userInfo = ["nextPosture": nextPosture.rawValue]

        let interval = max(fireAt.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
