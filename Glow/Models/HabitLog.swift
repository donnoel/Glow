import Foundation
import SwiftData

@Model
final class HabitLog {
    private static let calendar = Calendar.current

    var date: Date          // normalized to start-of-day
    var completed: Bool
    @Relationship var habit: Habit?

    init(date: Date, completed: Bool, habit: Habit?) {
        self.date = HabitLog.calendar.startOfDay(for: date)
        self.completed = completed
        self.habit = habit
    }
    
    convenience init(completed: Bool, habit: Habit?) {
        self.init(date: Date(), completed: completed, habit: habit)
    }
}
