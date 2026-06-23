import Foundation
import UserNotifications

nonisolated struct NotificationScheduleSnapshot: Sendable {
    let habitID: String
    let title: String
    let isArchived: Bool
    let schedule: HabitSchedule
    let reminderEnabled: Bool
    let reminderHour: Int?
    let reminderMinute: Int?

    @MainActor
    init(habit: Habit) {
        self.habitID = habit.id
        self.title = habit.title
        self.isArchived = habit.isArchived
        self.schedule = habit.schedule
        self.reminderEnabled = habit.reminderEnabled
        self.reminderHour = habit.reminderHour
        self.reminderMinute = habit.reminderMinute
    }

    var reminderTimeComponents: DateComponents? {
        guard reminderEnabled,
              let reminderHour,
              let reminderMinute
        else {
            return nil
        }

        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        return components
    }
}

protocol NotificationScheduling {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationScheduling { }

enum NotificationManager {
    /// Injection point for tests. Defaults to the real notification center.
    static var center: NotificationScheduling = UNUserNotificationCenter.current()
    private static let coalescer = NotificationSyncCoalescer()
    
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
    private static func scheduledWeekdays(for snapshot: NotificationScheduleSnapshot) -> [Weekday] {
        switch snapshot.schedule.kind {
        case .daily:
            return Array(Weekday.allCases)
        case .custom:
            return Array(snapshot.schedule.days).sorted { $0.rawValue < $1.rawValue }
        }
    }
    
    /// Canonical identifier for a habit's per-weekday notification.
    private static func identifier(for snapshot: NotificationScheduleSnapshot, weekday: Weekday) -> String {
        "habit.\(snapshot.habitID).weekday.\(weekday.rawValue)"
    }
    
    /// Computes the notification identifiers that should be active for a given habit,
    /// based on its schedule and reminder configuration.
    @MainActor
    static func notificationIdentifiers(for habit: Habit) -> [String] {
        notificationIdentifiers(for: NotificationScheduleSnapshot(habit: habit))
    }

    static func notificationIdentifiers(for snapshot: NotificationScheduleSnapshot) -> [String] {
        // Only care that a time exists; enabled flag is handled by callers.
        guard snapshot.reminderTimeComponents != nil else {
            return []
        }
        
        let days = scheduledWeekdays(for: snapshot)
        guard !days.isEmpty else { return [] }
        
        return days.map { identifier(for: snapshot, weekday: $0) }
    }
    
    // MARK: - Scheduling
    
    @MainActor
    static func scheduleNotifications(for habit: Habit) async {
        await scheduleNotifications(for: NotificationScheduleSnapshot(habit: habit))
    }

    static func scheduleNotifications(for snapshot: NotificationScheduleSnapshot) async {
        let scheduler = center
        await withCoalescedOperation(for: snapshot.habitID) { operationID in
            await scheduleNotifications(for: snapshot, operationID: operationID, scheduler: scheduler)
        }
    }

    private static func scheduleNotifications(
        for snapshot: NotificationScheduleSnapshot,
        operationID: Int,
        scheduler: NotificationScheduling
    ) async {
        // Guard out early for invalid / disabled cases.
        guard !snapshot.isArchived,
              snapshot.reminderEnabled,
              let time = snapshot.reminderTimeComponents
        else {
            return
        }
        
        // Clear old first to keep it idempotent.
        removePendingNotifications(for: snapshot, scheduler: scheduler)
        guard await isCurrentOperation(operationID, for: snapshot.habitID) else { return }
        
        let days = scheduledWeekdays(for: snapshot)
        guard !days.isEmpty else { return }
        
        for day in days {
            guard await isCurrentOperation(operationID, for: snapshot.habitID) else { return }

            var dc = DateComponents()
            dc.weekday = day.rawValue      // 1=Sun … 7=Sat (must match Weekday.rawValue)
            dc.hour = time.hour
            dc.minute = time.minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            
            let content = UNMutableNotificationContent()
            content.title = "Glow"
            content.subtitle = snapshot.title
            content.body = "How was your \(snapshot.title) today?"
            content.sound = .default
            
            let id = identifier(for: snapshot, weekday: day)
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            
            do {
                try await scheduler.add(req)
            } catch {
                // Intentionally ignore; failed schedules shouldn't crash the app.
            }
        }
    }

    // MARK: - Consistency helpers

    /// Sync reminder scheduling after creating a habit.
    @MainActor
    static func syncAfterCreate(for habit: Habit) async {
        await syncAfterCreate(for: NotificationScheduleSnapshot(habit: habit))
    }

    static func syncAfterCreate(for snapshot: NotificationScheduleSnapshot) async {
        guard snapshot.reminderEnabled, !snapshot.isArchived else { return }
        let scheduler = center
        await withCoalescedOperation(for: snapshot.habitID) { operationID in
            await requestAndScheduleIfPossible(for: snapshot, operationID: operationID, scheduler: scheduler)
        }
    }

    /// Sync reminder scheduling after editing a habit or reminder fields.
    @MainActor
    static func syncAfterEdit(for habit: Habit, wasReminderEnabled: Bool) async {
        await syncAfterEdit(for: NotificationScheduleSnapshot(habit: habit), wasReminderEnabled: wasReminderEnabled)
    }

    static func syncAfterEdit(for snapshot: NotificationScheduleSnapshot, wasReminderEnabled: Bool) async {
        let scheduler = center
        await withCoalescedOperation(for: snapshot.habitID) { operationID in
            await syncAfterEdit(
                for: snapshot,
                wasReminderEnabled: wasReminderEnabled,
                operationID: operationID,
                scheduler: scheduler
            )
        }
    }

    private static func syncAfterEdit(
        for snapshot: NotificationScheduleSnapshot,
        wasReminderEnabled: Bool,
        operationID: Int,
        scheduler: NotificationScheduling
    ) async {
        if snapshot.isArchived {
            removePendingNotifications(for: snapshot, scheduler: scheduler)
            return
        }

        if snapshot.reminderEnabled {
            await requestAndScheduleIfPossible(for: snapshot, operationID: operationID, scheduler: scheduler)
        } else if wasReminderEnabled {
            removePendingNotifications(for: snapshot, scheduler: scheduler)
        }
    }

    /// Sync reminder scheduling when archive state changes.
    @MainActor
    static func syncAfterArchiveStateChange(for habit: Habit) async {
        await syncAfterArchiveStateChange(for: NotificationScheduleSnapshot(habit: habit))
    }

    static func syncAfterArchiveStateChange(for snapshot: NotificationScheduleSnapshot) async {
        let scheduler = center
        await withCoalescedOperation(for: snapshot.habitID) { operationID in
            await syncAfterArchiveStateChange(for: snapshot, operationID: operationID, scheduler: scheduler)
        }
    }

    private static func syncAfterArchiveStateChange(
        for snapshot: NotificationScheduleSnapshot,
        operationID: Int,
        scheduler: NotificationScheduling
    ) async {
        if snapshot.isArchived {
            removePendingNotifications(for: snapshot, scheduler: scheduler)
        } else if snapshot.reminderEnabled {
            await requestAndScheduleIfPossible(for: snapshot, operationID: operationID, scheduler: scheduler)
        } else {
            // Defensive cleanup in case stale requests exist.
            removePendingNotifications(for: snapshot, scheduler: scheduler)
        }
    }
    
    // MARK: - Cancellation
    
    @MainActor
    static func cancelNotifications(for habit: Habit) async {
        await cancelNotifications(for: NotificationScheduleSnapshot(habit: habit))
    }

    static func cancelNotifications(for snapshot: NotificationScheduleSnapshot) async {
        let scheduler = center
        await withCoalescedOperation(for: snapshot.habitID) { _ in
            removePendingNotifications(for: snapshot, scheduler: scheduler)
        }
    }

    private static func removePendingNotifications(
        for snapshot: NotificationScheduleSnapshot,
        scheduler: NotificationScheduling
    ) {
        // Cancel every possible notification for this habit,
        // regardless of current schedule or reminder state.
        let ids = Weekday.allCases.map { identifier(for: snapshot, weekday: $0) }
        scheduler.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func requestAndScheduleIfPossible(
        for snapshot: NotificationScheduleSnapshot,
        operationID: Int,
        scheduler: NotificationScheduling
    ) async {
        let ok = await requestAuthorizationIfNeeded()
        guard ok else { return }
        guard await isCurrentOperation(operationID, for: snapshot.habitID) else { return }
        await scheduleNotifications(for: snapshot, operationID: operationID, scheduler: scheduler)
    }

    private static func withCoalescedOperation(
        for habitID: String,
        operation: (Int) async -> Void
    ) async {
        let operationID = await coalescer.begin(for: habitID)
        await operation(operationID)
        await coalescer.finish(operationID, for: habitID)
    }

    private static func isCurrentOperation(_ operationID: Int, for habitID: String) async -> Bool {
        await coalescer.isCurrent(operationID, for: habitID)
    }
}

private actor NotificationSyncCoalescer {
    private var operationIDs: [String: Int] = [:]

    func begin(for habitID: String) -> Int {
        let nextID = (operationIDs[habitID] ?? 0) + 1
        operationIDs[habitID] = nextID
        return nextID
    }

    func isCurrent(_ operationID: Int, for habitID: String) -> Bool {
        operationIDs[habitID] == operationID
    }

    func finish(_ operationID: Int, for habitID: String) {
        if operationIDs[habitID] == operationID {
            operationIDs.removeValue(forKey: habitID)
        }
    }
}
