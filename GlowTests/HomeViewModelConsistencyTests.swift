import Testing
@testable import Glow
import Foundation

@MainActor
struct HomeViewModelConsistencyTests {

    private var cal: Calendar { .current }

    private var today: Date {
        cal.startOfDay(for: Date())
    }

    private func dailySchedule() -> HabitSchedule {
        HabitSchedule(kind: .daily, days: [])
    }

    private func makeHabit(
        title: String,
        logs: [HabitLog] = []
    ) -> Habit {
        let h = Habit(
            title: title,
            createdAt: .now,
            isArchived: false,
            schedule: dailySchedule(),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "checkmark.circle",
            sortOrder: 0
        )
        h.logs = logs
        return h
    }

    private func log(on date: Date, for habit: Habit) -> HabitLog {
        HabitLog(date: date, completed: true, habit: habit)
    }

    @Test
    func picks_habit_with_most_distinct_days_in_last_14() async throws {
        let vm = HomeViewModel(today: today)

        // build dates
        let day1 = today
        let day2 = cal.date(byAdding: .day, value: -1, to: today)!
        let day3 = cal.date(byAdding: .day, value: -2, to: today)!

        // habit A done 3 separate days
        let habitA = makeHabit(title: "A")
        habitA.logs = [
            log(on: day1, for: habitA),
            log(on: day2, for: habitA),
            log(on: day3, for: habitA)
        ]

        // habit B done 1 day
        let habitB = makeHabit(title: "B")
        habitB.logs = [
            log(on: day1, for: habitB)
        ]

        await vm.updateHabits([habitA, habitB])

        let result = vm.mostConsistentHabit
        #expect(result.title == "A")
        #expect(result.hits == 3)
        #expect(result.window == 14)
    }

    @Test
    func multiple_logs_same_day_count_as_one() async throws {
        let vm = HomeViewModel(today: today)

        let habit = makeHabit(title: "Spammy")

        // two logs on the same day
        let log1 = HabitLog(date: today, completed: true, habit: habit)
        let log2 = HabitLog(date: today.addingTimeInterval(60 * 60), completed: true, habit: habit)
        habit.logs = [log1, log2]

        await vm.updateHabits([habit])

        let result = vm.mostConsistentHabit
        #expect(result.title == "Spammy")
        #expect(result.hits == 1) // same day -> 1 distinct day
    }

    @Test
    func returns_dash_when_no_habits_have_logs() async throws {
        let vm = HomeViewModel(today: today)

        let h1 = makeHabit(title: "Empty 1")
        let h2 = makeHabit(title: "Empty 2")

        await vm.updateHabits([h1, h2])

        let result = vm.mostConsistentHabit
        #expect(result.title == "—")  // matches the default you used
        #expect(result.hits == 0)
    }
}
