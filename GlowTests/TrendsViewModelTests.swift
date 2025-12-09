import Testing
@testable import Glow
import Foundation

@MainActor
struct TrendsViewModelTests {
    private func dailySchedule() -> HabitSchedule {
        HabitSchedule(kind: .daily, days: [])
    }

    private var cal: Calendar { .current }

    private var today: Date {
        cal.startOfDay(for: Date())
    }

    @Test
    func archived_habits_are_excluded_from_global_activity() throws {
        let active = Habit(title: "Active", schedule: dailySchedule())
        let archived = Habit(title: "Archived", schedule: dailySchedule(), isArchived: true)

        // Only the archived habit has activity today.
        archived.logs = [HabitLog(date: today, completed: true, habit: archived)]
        active.logs = []

        let model = TrendsViewModel(habits: [active, archived], now: today)

        #expect(model.globalStreaks.current == 0)
        #expect(model.globalStreaks.best == 0)
        #expect(model.weeklyActiveDaysCount == 0)
    }
}
