import Foundation
import UserNotifications

/// Water notifications should still tap the wrist while Glow is visible during a check-in.
nonisolated final class GlowWatchWaterNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        guard identifier.hasPrefix(WaterNudgePlanner.identifierPrefix) else {
            return []
        }
        return [.banner, .sound]
    }
}
