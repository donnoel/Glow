import Testing
@testable import Glow
import Foundation

@MainActor
struct MonthHeatmapModelTests {

    private let cal = Calendar.current

    private var today: Date {
        cal.startOfDay(for: Date())
    }

    @Test
    func current_month_percent_uses_elapsed_days() throws {
        let habit = Habit(title: "Percent Test")

        // Start at the first of this month.
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: today)) else {
            Issue.record("Could not compute start of month")
            return
        }

        // Create a completion for every day from day 1 through today (inclusive).
        let daysElapsed = cal.component(.day, from: today)
        let logs: [HabitLog] = (0..<daysElapsed).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: startOfMonth) else { return nil }
            return HabitLog(date: day, completed: true, habit: habit)
        }

        let model = MonthHeatmapModel(habit: habit, month: today, logs: logs)

        // With all elapsed days completed, percent should be 100 even mid-month.
        #expect(model.pct == 100)
    }

    @Test
    func past_month_streak_anchors_to_selected_month_end() throws {
        let habit = Habit(title: "Past Month Streak")

        guard let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: today)),
              let startOfPreviousMonth = cal.date(byAdding: .month, value: -1, to: startOfThisMonth),
              let lastDayOfPreviousMonth = cal.date(byAdding: .day, value: -1, to: startOfThisMonth)
        else {
            Issue.record("Could not compute previous month dates")
            return
        }

        let logs: [HabitLog] = (0..<3).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: lastDayOfPreviousMonth) else {
                return nil
            }
            return HabitLog(date: day, completed: true, habit: habit)
        }

        let model = MonthHeatmapModel(habit: habit, month: startOfPreviousMonth, logs: logs)

        #expect(model.monthStreak == 3)
    }
}
