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
    
    // MARK: - Authorization
    
    static func requestAuthorizationIfNeeded() async -> Bool {
        // Use the real center for auth / settings.
        let systemCenter = UNUserNotificationCenter.current()
        let settings = await systemCenter.notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let ok = try await systemCenter.requestAuthorization(options: [.alert, .sound, .badge])
                return ok
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }
    
    // MARK: - Identifier helpers
    
    /// The weekdays this habit is scheduled on, based on its schedule.
    private static func scheduledWeekdays(for habit: Habit) -> [Weekday] {
        switch habit.schedule.kind {
        case .daily:
            return Array(Weekday.allCases)
        case .custom:
            return Array(habit.schedule.days).sorted { $0.rawValue < $1.rawValue }
        }
    }
    
    /// Canonical identifier for a habit's per-weekday notification.
    private static func identifier(for habit: Habit, weekday: Weekday) -> String {
        "habit.\(habit.id).weekday.\(weekday.rawValue)"
    }
    
    /// Computes the notification identifiers that should be active for a given habit,
    /// based on its schedule and reminder configuration.
    static func notificationIdentifiers(for habit: Habit) -> [String] {
        // Only care that a time exists; enabled flag is handled by callers.
        guard habit.reminderTimeComponents != nil else {
            return []
        }
        
        let days = scheduledWeekdays(for: habit)
        guard !days.isEmpty else { return [] }
        
        return days.map { identifier(for: habit, weekday: $0) }
    }
    
    // MARK: - Scheduling
    
    static func scheduleNotifications(for habit: Habit) async {
        // Guard out early for invalid / disabled cases.
        guard !habit.isArchived,
              habit.reminderEnabled,
              let time = habit.reminderTimeComponents
        else {
            return
        }
        
        // Clear old first to keep it idempotent.
        await cancelNotifications(for: habit)
        
        let days = scheduledWeekdays(for: habit)
        guard !days.isEmpty else { return }
        
        for day in days {
            var dc = DateComponents()
            dc.weekday = day.rawValue      // 1=Sun … 7=Sat (must match Weekday.rawValue)
            dc.hour = time.hour
            dc.minute = time.minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            
            let content = UNMutableNotificationContent()
            content.title = "Glow"
            content.subtitle = habit.title
            content.body = "Is now a good time?"
            content.sound = .default
            
            let id = identifier(for: habit, weekday: day)
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            
            do {
                try await center.add(req)
            } catch {
                // Intentionally ignore; failed schedules shouldn't crash the app.
            }
        }
    }
    
    // MARK: - Cancellation
    
    static func cancelNotifications(for habit: Habit) async {
        // Cancel every possible notification for this habit,
        // regardless of current schedule or reminder state.
        let ids = Weekday.allCases.map { identifier(for: habit, weekday: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
