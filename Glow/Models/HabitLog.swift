import Foundation
import SwiftData

@Model
final class HabitLog {
    var date: Date          // normalized to start-of-day
    var completed: Bool
    @Relationship var habit: Habit?

    init(date: Date, completed: Bool, habit: Habit?) {
        self.date = Calendar.current.startOfDay(for: date)
        self.completed = completed
        self.habit = habit
    }
}
