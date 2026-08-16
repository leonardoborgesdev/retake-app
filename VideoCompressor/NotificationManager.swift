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
    /// Kept alive for the process lifetime by being assigned to
    /// UNUserNotificationCenter's delegate property, which holds a weak reference -
    /// without a strong reference living somewhere, this would be deallocated
    /// immediately and the delegate callback would never fire.
    private static let foregroundPresenter = ForegroundPresenter()

    static func configure() {
        UNUserNotificationCenter.current().delegate = foregroundPresenter
    }

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

/// Without this, iOS silently drops local notifications fired while the app is in the
/// foreground - exactly the moment a compress/cut/split job finishes while someone is
/// watching. This opts back in to showing the banner and sound even then.
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
