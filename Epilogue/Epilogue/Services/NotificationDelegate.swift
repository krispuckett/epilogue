import UserNotifications
import SwiftUI

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        // Check if this is a reading reminder
        if let bookId = userInfo["bookId"] as? String {
            // Navigate to the book
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToBookFromNotification"),
                    object: bookId
                )
            }
        }
        
        // Check if this is a general reading reminder
        if userInfo["type"] as? String == "readingReminder" {
            // Navigate to library tab
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToTab"),
                    object: 0 // Library tab
                )
            }
        }
        
        completionHandler()
    }
}