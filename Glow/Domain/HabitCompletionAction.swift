import Foundation
import SwiftData

@MainActor
enum HabitCompletionAction {
    /// Set an explicit status; replaying a Watch packet must never toggle it.
    static func setCompleted(_ completed: Bool, for habit: Habit, on day: Date, in context: ModelContext) {
        let logs = (habit.logs ?? []).filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
        if logs.isEmpty {
            if completed { context.insert(HabitLog(date: day, completed: true, habit: habit)) }
        } else {
            // Keep the daily status consistent even if CloudKit previously merged duplicate logs.
            for log in logs { log.completed = completed }
        }
    }
}
