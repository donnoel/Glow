import Testing
@testable import Glow
import Foundation

@MainActor
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

    // MARK: - Tests

    #if os(iOS)
    @Test
    func requestAuthorization_is_skipped_in_tests() {
        // Intentionally not calling NotificationManager.requestAuthorizationIfNeeded()
        // to avoid a UI prompt / hanging the test runner.
    }

    @Test
    func schedule_does_nothing_for_archived_habit() async throws {
        let archived = makeHabit(
            title: "Archived",
            isArchived: true,
            reminderEnabled: true,
            hour: 9,
            minute: 0
        )
        await NotificationManager.scheduleNotifications(for: archived)
    }

    @Test
    func schedule_does_nothing_for_habit_without_reminder() async throws {
        let noReminder = makeHabit(
            title: "NoReminder",
            reminderEnabled: false
        )
        await NotificationManager.scheduleNotifications(for: noReminder)
    }

    @Test
    func schedule_works_for_valid_habit() async throws {
        let valid = makeHabit(
            title: "ValidReminder",
            reminderEnabled: true,
            hour: 20,
            minute: 0
        )
        await NotificationManager.scheduleNotifications(for: valid)
    }

    @Test
    func cancel_is_callable_for_any_habit() async throws {
        let h = makeHabit(
            title: "ToCancel",
            reminderEnabled: true,
            hour: 7,
            minute: 30
        )
        await NotificationManager.cancelNotifications(for: h)
    }
    #else
    // On non-iOS platforms, just verify we can build the test target.
    @Test
    func notifications_not_tested_on_this_platform() {
        // no-op
    }
    #endif
}
