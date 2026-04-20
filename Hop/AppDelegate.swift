import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        NotificationManager.shared.registerCategories()

        Task {
            _ = await NotificationManager.shared.requestAuthorization()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func didWake() {
        Task { @MainActor in PostureScheduler.shared.handleWake() }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        let nextPosture = (userInfo["nextPosture"] as? String).flatMap(Posture.init(rawValue:)) ?? .standing

        let mapped: NotificationAction? = {
            switch actionId {
            case NotificationAction.switched.rawValue: return .switched
            case NotificationAction.snooze.rawValue:   return .snooze
            case NotificationAction.skip.rawValue:     return .skip
            case UNNotificationDefaultActionIdentifier: return .switched
            default: return nil
            }
        }()

        #if DEBUG
        NSLog("[Hop] Notification action=\(actionId) nextPosture=\(nextPosture.rawValue) mapped=\(mapped?.rawValue ?? "nil")")
        #endif

        if let mapped {
            Task { @MainActor in
                PostureScheduler.shared.handleNotificationAction(mapped, nextPosture: nextPosture)
            }
        }
        completionHandler()
    }
}
