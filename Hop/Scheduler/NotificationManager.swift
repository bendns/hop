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
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    /// Hop keeps at most one reminder around, so a fixed identifier makes each
    /// new request replace the previous one.
    private let identifier = "hop.notification.next"

    func registerCategories() {
        let switched = UNNotificationAction(
            identifier: NotificationAction.switched.rawValue,
            title: "Done, switched",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Snooze 10 min",
            options: []
        )
        let skip = UNNotificationAction(
            identifier: NotificationAction.skip.rawValue,
            title: "Skip this round",
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
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Schedules exactly one posture-switch notification at `fireAt`.
    /// Replaces any previously-scheduled or delivered notification.
    func schedule(nextPosture: Posture, fireAt: Date) {
        cancelAll()
        let content = UNMutableNotificationContent()
        let message = Self.messages[nextPosture]!.randomElement()!
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.postureSwitch.rawValue
        content.userInfo = ["nextPosture": nextPosture.rawValue]

        let interval = max(fireAt.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Also removes delivered notifications: acting on a stale banner would
    /// otherwise flip the posture to an outdated target.
    /// A few variations so reminders don't feel robotic.
    private static let messages: [Posture: [(title: String, body: String)]] = [
        .standing: [
            ("Time to stand up", "Raise the desk and give your back a break."),
            ("Up you hop!", "A little standing goes a long way."),
            ("Stretch your legs", "You've been sitting for a while. Let's switch."),
        ],
        .sitting: [
            ("Time to sit down", "Nice standing streak. Rest your legs for a bit."),
            ("Take a seat", "Good work on your feet. Time to switch."),
            ("Rest those legs", "Lower the desk and settle in."),
        ],
    ]

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
