import Testing
@testable import Glow
import Foundation

struct ReminderFilteringTests {

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
        let h = Habit(
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
        return h
    }

    /// This matches what RemindersView conceptually does:
    /// filter to reminder-enabled, non-archived, valid time, then sort by time
    private func reminderHabits(from habits: [Habit]) -> [Habit] {
        habits
            .filter { !$0.isArchived }
            .filter { $0.reminderEnabled }
            .filter { $0.reminderHour != nil && $0.reminderMinute != nil }
            .sorted { lhs, rhs in
                let lHour = lhs.reminderHour ?? 23
                let lMin = lhs.reminderMinute ?? 59
                let rHour = rhs.reminderHour ?? 23
                let rMin = rhs.reminderMinute ?? 59
                if lHour == rHour {
                    return lMin < rMin
                }
                return lHour < rHour
            }
    }

    // MARK: - Tests

    @Test
    func excludes_archived_habits() throws {
        let h1 = makeHabit(title: "Keep me", reminderEnabled: true, hour: 9, minute: 0)
        let h2 = makeHabit(title: "Archived", isArchived: true, reminderEnabled: true, hour: 10, minute: 0)

        let filtered = reminderHabits(from: [h1, h2])

        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Keep me")
    }

    @Test
    func excludes_habits_with_reminder_off() throws {
        let h1 = makeHabit(title: "On", reminderEnabled: true, hour: 9, minute: 0)
        let h2 = makeHabit(title: "Off", reminderEnabled: false, hour: 8, minute: 0)

        let filtered = reminderHabits(from: [h1, h2])

        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "On")
    }

    @Test
    func excludes_habits_with_missing_time() throws {
        let h1 = makeHabit(title: "Good", reminderEnabled: true, hour: 9, minute: 0)
        let h2 = makeHabit(title: "NoHour", reminderEnabled: true, hour: nil, minute: 15)
        let h3 = makeHabit(title: "NoMinute", reminderEnabled: true, hour: 7, minute: nil)

        let filtered = reminderHabits(from: [h1, h2, h3])

        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Good")
    }

    @Test
    func sorts_by_time_ascending() throws {
        let h1 = makeHabit(title: "9am", reminderEnabled: true, hour: 9, minute: 0)
        let h2 = makeHabit(title: "7:30am", reminderEnabled: true, hour: 7, minute: 30)
        let h3 = makeHabit(title: "7:45am", reminderEnabled: true, hour: 7, minute: 45)

        let filtered = reminderHabits(from: [h1, h2, h3])

        #expect(filtered.map(\.title) == ["7:30am", "7:45am", "9am"])
    }
}
