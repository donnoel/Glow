import Foundation
import UserNotifications

protocol NotificationScheduling {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationScheduling { }

enum NotificationManager {
    /// Injection point for tests. Defaults to the real notification center.
    static var center: NotificationScheduling = UNUserNotificationCenter.current()

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

    /// Computes the notification identifiers that should be active for a given habit,
    /// based on its schedule and reminder configuration.
    static func notificationIdentifiers(for habit: Habit) -> [String] {
        guard habit.reminderEnabled, habit.reminderTimeComponents != nil else {
            return []
        }

        let days: [Weekday]
        switch habit.schedule.kind {
        case .daily:
            days = Array(Weekday.allCases)
        case .custom:
            days = Array(habit.schedule.days).sorted { $0.rawValue < $1.rawValue }
        }

        return days.map { day in
            "habit.\(habit.id).weekday.\(day.rawValue)"
        }
    }

    static func scheduleNotifications(for habit: Habit) async {
        guard !habit.isArchived, habit.reminderEnabled, let time = habit.reminderTimeComponents else { return }        // Clear old first to keep it idempotent
        await cancelNotifications(for: habit)

        let ids = notificationIdentifiers(for: habit)
        guard !ids.isEmpty else { return }

        // We need the corresponding weekdays to build proper triggers. Derive them from the ids.
        // Each id is of the form "habit.<id>.weekday.<rawValue>".
        for id in ids {
            guard let weekdayRaw = Int(id.split(separator: ".").last ?? ""),
                  let day = Weekday(rawValue: weekdayRaw) else {
                continue
            }

            var dc = DateComponents()
            dc.weekday = day.rawValue        // 1=Sun … 7=Sat
            dc.hour = time.hour
            dc.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "Glow"
            content.subtitle = habit.title
            content.body = "Is now a good time?"
            content.sound = .default

            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do { try await Self.center.add(req) } catch { /* ignore */ }
        }
    }

    static func cancelNotifications(for habit: Habit) async {
        let ids = notificationIdentifiers(for: habit)
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
