import Testing
@testable import Glow
import Foundation
import UserNotifications

@MainActor
@Suite(.serialized)
struct NotificationManagerTests {
    
    // MARK: - Helpers
    
    private func dailySchedule() -> HabitSchedule {
        HabitSchedule(kind: .daily, days: [])
    }
    
    private func makeHabit(
        title: String,
        isArchived: Bool = false,
        reminderEnabled: Bool = false,
        hour: Int? = nil,
        minute: Int? = nil
    ) -> Habit {
        Habit(
            title: title,
            createdAt: .now,
            isArchived: isArchived,
            schedule: dailySchedule(),
            reminderEnabled: reminderEnabled,
            reminderHour: hour,
            reminderMinute: minute,
            iconName: "checkmark.circle",
            sortOrder: 0
        )
    }

    private func allNotificationIdentifiers(for habit: Habit) -> [String] {
        Weekday.allCases.map { "habit.\(habit.id).weekday.\($0.rawValue)" }
    }
    
    /// Fake notification center used for tests to avoid hitting the real UNUserNotificationCenter.
    final class FakeNotificationCenter: NotificationScheduling {
        private(set) var addedRequests: [UNNotificationRequest] = []
        private(set) var pendingRequests: [UNNotificationRequest] = []
        private(set) var removedIdentifiers: [[String]] = []
        private(set) var removedDeliveredIdentifiers: [[String]] = []
        
        func add(_ request: UNNotificationRequest) async throws {
            addedRequests.append(request)
        }

        func pendingNotificationRequests() async -> [UNNotificationRequest] {
            pendingRequests
        }
        
        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            removedIdentifiers.append(identifiers)
        }

        func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
            removedDeliveredIdentifiers.append(identifiers)
        }

        func setPendingIdentifiers(_ identifiers: [String]) {
            pendingRequests = identifiers.map {
                UNNotificationRequest(identifier: $0, content: UNMutableNotificationContent(), trigger: nil)
            }
        }
        
        func reset() {
            addedRequests.removeAll()
            pendingRequests.removeAll()
            removedIdentifiers.removeAll()
            removedDeliveredIdentifiers.removeAll()
        }
    }
    
    // MARK: - Tests
    
    #if os(iOS)
    
    @Test
    func schedule_does_not_schedule_for_archived_habit() async {
        let fakeCenter = FakeNotificationCenter()
        NotificationManager.center = fakeCenter
        defer { NotificationManager.center = UNUserNotificationCenter.current() }
        
        let archived = makeHabit(
            title: "Archived",
            isArchived: true,
            reminderEnabled: true,
            hour: 9,
            minute: 0
        )
        
        let expectedIds = NotificationManager.notificationIdentifiers(for: archived)
        // Sanity: archived habits with reminders still compute identifiers, but the main guard
        // in scheduleNotifications(for:) should prevent scheduling.
        #expect(!expectedIds.isEmpty)
        
        await NotificationManager.scheduleNotifications(for: archived)
        
        #expect(fakeCenter.addedRequests.isEmpty, "Archived habits should not schedule notifications")
    }
    
    @Test
    func schedule_does_not_schedule_for_habit_without_reminder() async {
        let fakeCenter = FakeNotificationCenter()
        NotificationManager.center = fakeCenter
        defer { NotificationManager.center = UNUserNotificationCenter.current() }
        
        let noReminder = makeHabit(
            title: "NoReminder",
            reminderEnabled: false
        )
        
        let expectedIds = NotificationManager.notificationIdentifiers(for: noReminder)
        // With reminders disabled, we should not even derive identifiers.
        #expect(expectedIds.isEmpty)
        
        await NotificationManager.scheduleNotifications(for: noReminder)
        
        #expect(fakeCenter.addedRequests.isEmpty, "Habits with reminders disabled should not schedule notifications")
    }
    
    @Test
    func schedule_schedules_for_valid_habit() async {
        let fakeCenter = FakeNotificationCenter()
        NotificationManager.center = fakeCenter
        defer { NotificationManager.center = UNUserNotificationCenter.current() }
        
        let valid = makeHabit(
            title: "ValidReminder",
            reminderEnabled: true,
            hour: 20,
            minute: 0
        )
        
        let expectedIds = NotificationManager.notificationIdentifiers(for: valid)
        #expect(!expectedIds.isEmpty, "Valid reminder-enabled habit should have at least one identifier")
        
        await NotificationManager.scheduleNotifications(for: valid)
        
        let added = fakeCenter.addedRequests
        #expect(!added.isEmpty, "Valid reminder-enabled habit should schedule at least one notification")
        
        let addedIds = Set(added.map(\.identifier))
        #expect(addedIds == Set(expectedIds), "Scheduled notification identifiers should match expected identifiers")
    }
    
    @Test
    func cancel_clears_scheduled_notifications_for_habit() async {
        let fakeCenter = FakeNotificationCenter()
        NotificationManager.center = fakeCenter
        defer { NotificationManager.center = UNUserNotificationCenter.current() }
        
        let habit = makeHabit(
            title: "ToCancel",
            reminderEnabled: true,
            hour: 7,
            minute: 30
        )
        
        let expectedIds = NotificationManager.notificationIdentifiers(for: habit)
        #expect(!expectedIds.isEmpty, "Valid habit should compute identifiers for cancellation")
        
        // First schedule
        await NotificationManager.scheduleNotifications(for: habit)
        #expect(!fakeCenter.addedRequests.isEmpty, "Precondition: scheduling should create pending notifications")
        
        // Then cancel
        await NotificationManager.cancelNotifications(for: habit)
        
        // Assert that cancel attempted to remove the expected identifiers
        #expect(
            fakeCenter.removedIdentifiers.contains(where: { $0 == expectedIds }),
            "Cancel should attempt to remove pending notifications for the habit"
        )
        #expect(
            fakeCenter.removedDeliveredIdentifiers.contains(where: { $0 == expectedIds }),
            "Cancel should also clear already delivered notifications for the habit"
        )
    }

    @Test
    func reconciliation_removes_only_notifications_without_an_active_reminder() async {
        let fakeCenter = FakeNotificationCenter()
        NotificationManager.center = fakeCenter
        defer { NotificationManager.center = UNUserNotificationCenter.current() }

        let active = makeHabit(
            title: "Active",
            reminderEnabled: true,
            hour: 8,
            minute: 0
        )
        let validIdentifier = allNotificationIdentifiers(for: active)[0]
        let orphanedIdentifier = "habit.deleted-practice.weekday.2"
        let unrelatedIdentifier = "another-feature.notification"
        fakeCenter.setPendingIdentifiers([
            validIdentifier,
            orphanedIdentifier,
            unrelatedIdentifier
        ])

        await NotificationManager.removeStaleNotifications(
            validSnapshots: [NotificationScheduleSnapshot(habit: active)]
        )

        #expect(fakeCenter.removedIdentifiers == [[orphanedIdentifier]])
        #expect(fakeCenter.removedDeliveredIdentifiers == [[orphanedIdentifier]])
    }

    @Test
    func syncAfterEdit_removes_pending_notifications_when_reminder_is_turned_off() async {
        let fakeCenter = FakeNotificationCenter()
        NotificationManager.center = fakeCenter
        defer { NotificationManager.center = UNUserNotificationCenter.current() }

        let habit = makeHabit(
            title: "TurnedOff",
            reminderEnabled: false,
            hour: 8,
            minute: 15
        )
        let expectedIds = allNotificationIdentifiers(for: habit)

        await NotificationManager.syncAfterEdit(for: habit, wasReminderEnabled: true)

        #expect(fakeCenter.addedRequests.isEmpty)
        #expect(
            fakeCenter.removedIdentifiers.contains(where: { $0 == expectedIds }),
            "Turning a reminder off should clear all pending weekday requests"
        )
    }

    @Test
    func syncAfterArchiveStateChange_removes_pending_notifications_when_archived() async {
        let fakeCenter = FakeNotificationCenter()
        NotificationManager.center = fakeCenter
        defer { NotificationManager.center = UNUserNotificationCenter.current() }

        let habit = makeHabit(
            title: "ArchivedReminder",
            isArchived: true,
            reminderEnabled: true,
            hour: 9,
            minute: 30
        )
        let expectedIds = allNotificationIdentifiers(for: habit)

        await NotificationManager.syncAfterArchiveStateChange(for: habit)

        #expect(fakeCenter.addedRequests.isEmpty)
        #expect(
            fakeCenter.removedIdentifiers.contains(where: { $0 == expectedIds }),
            "Archiving a habit should clear all pending weekday requests"
        )
    }
    
    #else
    // On non-iOS platforms, just verify we can build the test target.
    @Test
    func notifications_not_tested_on_this_platform() {
        // no-op
    }
    #endif
}
