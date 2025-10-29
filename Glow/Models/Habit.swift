import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: String
    var title: String
    var createdAt: Date

    // Archive
    var isArchived: Bool

    // Schedule (persisted as Data)
    var scheduleData: Data

    // Logs
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog] = []

    // M7: Reminders
    var reminderEnabled: Bool
    var reminderHour: Int?
    var reminderMinute: Int?

    init(
        id: String = UUID().uuidString,
        title: String,
        createdAt: Date = .now,
        isArchived: Bool = false,
        schedule: HabitSchedule = .daily,
        reminderEnabled: Bool = false,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.scheduleData = (try? JSONEncoder().encode(schedule)) ?? Data()
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }
}

extension Habit {
    var schedule: HabitSchedule {
        get { (try? JSONDecoder().decode(HabitSchedule.self, from: scheduleData)) ?? .daily }
        set { scheduleData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // Convenience for M7
    var reminderTimeComponents: DateComponents? {
        guard reminderEnabled, let h = reminderHour, let m = reminderMinute else { return nil }
        var dc = DateComponents()
        dc.hour = h; dc.minute = m
        return dc
    }

    func setReminderTime(from date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        reminderHour = comps.hour
        reminderMinute = comps.minute
    }
}
