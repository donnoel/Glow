import Foundation
import UserNotifications

enum NotificationManager {
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let ok = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                return ok
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func scheduleNotifications(for habit: Habit) async {
        guard habit.reminderEnabled, let time = habit.reminderTimeComponents else { return }
        // Clear old first to keep it idempotent
        await cancelNotifications(for: habit)

        let center = UNUserNotificationCenter.current()
        let days: [Weekday]
        switch habit.schedule.kind {
        case .daily: days = Array(Weekday.allCases)
        case .custom: days = Array(habit.schedule.days).sorted { $0.rawValue < $1.rawValue }
        }

        for day in days {
            var dc = DateComponents()
            dc.weekday = day.rawValue        // 1=Sun … 7=Sat
            dc.hour = time.hour
            dc.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "glow"
            content.subtitle = habit.title
            content.body = "It’s time to complete your habit."
            content.sound = .default

            let id = "habit.\(habit.id).weekday.\(day.rawValue)"
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do { try await center.add(req) } catch { /* ignore */ }
        }
    }

    static func cancelNotifications(for habit: Habit) async {
        let ids = Weekday.allCases.map { "habit.\(habit.id).weekday.\($0.rawValue)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
