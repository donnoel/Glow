import Testing
@testable import Glow
import Foundation

struct HabitTests {

    private func dailySchedule() -> HabitSchedule {
        HabitSchedule(kind: .daily, days: [])
    }

    @Test
    func init_sets_basic_fields() throws {
        let h = Habit(
            title: "Meditate",
            createdAt: .now,
            isArchived: false,
            schedule: dailySchedule(),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "checkmark.circle",
            sortOrder: 5
        )

        #expect(h.title == "Meditate")
        #expect(h.isArchived == false)
        #expect(h.sortOrder == 5)
        #expect(h.schedule.kind == .daily)
    }

    @Test
    func reminder_fields_can_be_set() throws {
        var h = Habit(
            title: "Evening walk",
            createdAt: .now,
            isArchived: false,
            schedule: dailySchedule(),
            reminderEnabled: true,
            reminderHour: 20,
            reminderMinute: 15,
            iconName: "figure.walk",
            sortOrder: 0
        )

        #expect(h.reminderEnabled == true)
        #expect(h.reminderHour == 20)
        #expect(h.reminderMinute == 15)

        // flip it off
        h.reminderEnabled = false
        #expect(h.reminderEnabled == false)
    }

    @Test
    func archived_flag_round_trips() throws {
        let h = Habit(
            title: "Old habit",
            createdAt: .now,
            isArchived: true,
            schedule: dailySchedule(),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "archivebox",
            sortOrder: 0
        )

        #expect(h.isArchived == true)
    }

    @Test
    func logs_can_be_attached() throws {
        let habit = Habit(
            title: "Log me",
            createdAt: .now,
            isArchived: false,
            schedule: dailySchedule(),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "checkmark.circle",
            sortOrder: 0
        )

        let today = Calendar.current.startOfDay(for: Date())
        let log = HabitLog(date: today, completed: true, habit: habit)

        habit.logs = [log]

        #expect(habit.logs?.count == 1)
        #expect(habit.logs?.first?.completed == true)
        #expect(habit.logs?.first?.date == today)
    }

    @Test
    func placeholder_habit_exists() throws {
        // you use Habit.placeholder in streak math
        let placeholder = Habit.placeholder
        #expect(!placeholder.title.isEmpty)
    }
}
