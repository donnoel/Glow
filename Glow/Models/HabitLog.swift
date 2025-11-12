import Foundation
import SwiftData

@Model
final class HabitLog {
    private static let calendar = Calendar.current

    // Persisted
    var date: Date = Date()
    var completed: Bool = false

    @Relationship var habit: Habit?

    /// Normalizes to start-of-day and **clamps any future date back to today**.
    init(date: Date, completed: Bool, habit: Habit?) {
        let cal = HabitLog.calendar
        let startOfArg   = cal.startOfDay(for: date)
        let startOfToday = cal.startOfDay(for: Date())

        // Prevent future-dated logs
        let safeDate = min(startOfArg, startOfToday)

        self.date = safeDate
        // If a future date was passed, treat it as today; "completed" remains as requested.
        self.completed = completed
        self.habit = habit
    }

    /// Convenience init uses now; still normalized/clamped in the designated init.
    convenience init(completed: Bool, habit: Habit?) {
        self.init(date: Date(), completed: completed, habit: habit)
    }
}
