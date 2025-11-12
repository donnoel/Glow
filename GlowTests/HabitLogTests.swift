import Testing
@testable import Glow
import Foundation
@MainActor
struct HabitLogTests {

    @Test
    func init_sets_date_completed_and_habit() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let habit = Habit(
            title: "Logged habit",
            createdAt: .now,
            isArchived: false,
            schedule: HabitSchedule(kind: .daily, days: []),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "checkmark.circle",
            sortOrder: 0
        )

        let log = HabitLog(date: today, completed: true, habit: habit)

        #expect(log.date == today)
        #expect(log.completed == true)
        #expect(log.habit?.title == "Logged habit")
    }

    @Test
    func log_can_be_marked_incomplete() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let habit = Habit(
            title: "Toggle",
            createdAt: .now,
            isArchived: false,
            schedule: HabitSchedule(kind: .daily, days: []),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "checkmark.circle",
            sortOrder: 0
        )

        var log = HabitLog(date: today, completed: true, habit: habit)
        #expect(log.completed == true)

        log.completed = false
        #expect(log.completed == false)
    }

    @Test
    func habit_can_hold_multiple_logs() throws {
        let habit = Habit(
            title: "Multi-day",
            createdAt: .now,
            isArchived: false,
            schedule: HabitSchedule(kind: .daily, days: []),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "checkmark.circle",
            sortOrder: 0
        )

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let log1 = HabitLog(date: yesterday, completed: true, habit: habit)
        let log2 = HabitLog(date: today, completed: true, habit: habit)

        habit.logs = [log1, log2]

        #expect(habit.logs?.count == 2)
        #expect(habit.logs?.first?.habit?.title == "Multi-day")
    }
}
