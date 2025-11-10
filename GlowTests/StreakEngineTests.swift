import Testing
@testable import Glow
import Foundation

struct StreakEngineTests {

    // MARK: - Helpers

    private var cal: Calendar { .current }

    private func day(_ offset: Int) -> Date {
        // offset = 0 -> today, -1 -> yesterday, etc.
        let start = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: offset, to: start)!
    }

    private func log(on date: Date) -> HabitLog {
        // the engine only cares about date + completed
        HabitLog(date: date, completed: true, habit: Habit.placeholder)
    }

    // MARK: - Tests

    @Test
    func empty_logs_yield_zero_streaks() throws {
        let result = StreakEngine.computeStreaks(logs: [])
        #expect(result.current == 0)
        #expect(result.best == 0)
    }

    @Test
    func single_day_completion_gives_current_and_best_of_one() throws {
        let result = StreakEngine.computeStreaks(logs: [log(on: day(0))])
        #expect(result.current == 1)
        #expect(result.best == 1)
    }

    @Test
    func consecutive_days_count_up_in_current_and_best() throws {
        let logs = [
            log(on: day(0)),  // today
            log(on: day(-1)), // yesterday
            log(on: day(-2))  // 2 days ago
        ]
        let result = StreakEngine.computeStreaks(logs: logs)
        #expect(result.current == 3)
        #expect(result.best == 3)
    }

    @Test
    func gap_breaks_current_but_not_best() throws {
        let logs = [
            log(on: day(0)),   // today
            // gap yesterday
            log(on: day(-2)),  // two days ago
            log(on: day(-3)),  // three days ago
            log(on: day(-4))   // four days ago
        ]
        let result = StreakEngine.computeStreaks(logs: logs)

        // current is only today = 1
        #expect(result.current == 1)

        // best should pick up the longer run (days -2, -3, -4) = 3
        #expect(result.best >= 3)
    }

    @Test
    func out_of_order_logs_still_compute() throws {
        let logs = [
            log(on: day(-2)),
            log(on: day(0)),
            log(on: day(-1))
        ]
        let result = StreakEngine.computeStreaks(logs: logs)
        #expect(result.current == 3)
        #expect(result.best == 3)
    }

    @Test
    func multiple_logs_on_same_day_count_as_one_day() throws {
        let today = day(0)
        let logs = [
            HabitLog(date: today, completed: true, habit: Habit.placeholder),
            HabitLog(date: today.addingTimeInterval(60 * 60), completed: true, habit: Habit.placeholder)
        ]
        let result = StreakEngine.computeStreaks(logs: logs)
        #expect(result.current == 1)
        #expect(result.best == 1)
    }
}
