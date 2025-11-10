import Foundation
import SwiftData

@Model
final class HabitLog {
    private static let calendar = Calendar.current

    // give CloudKit defaults
    var date: Date = Date()
    var completed: Bool = false

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
