import Foundation
import UserNotifications

/// Fires a local notification when a compress/cut/split job finishes - lets the user
/// leave the app while it works and find out when it's done instead of staring at a
/// progress bar. iOS still only grants a limited window of extra background time after
/// the app is backgrounded (beginBackgroundTask, already used at each call site); this
/// does not make processing run indefinitely in the background, it just makes sure the
/// user is told the moment a job completes, whether that happens in the foreground or
/// during that grace window.
enum NotificationManager {
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    static func notifyJobFinished(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
