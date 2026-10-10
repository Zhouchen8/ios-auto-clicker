import Foundation
import UserNotifications

/// 本地通知（FR4.1/FR4.2）
enum NotificationService {
    static func sendCompletion(title: String, body: String) {
        send(title: title, body: body)
    }

    static func sendInterrupt(title: String, body: String) {
        send(title: title, body: body)
    }

    private static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
