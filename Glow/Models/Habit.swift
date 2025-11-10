import Foundation
import SwiftData

@Model
final class Habit {
    // was: @Attribute(.unique) var id: String
    // CloudKit doesn't support unique constraints, so drop the attribute
    var id: String = UUID().uuidString

    // add defaults so CloudKit is happy
    var title: String = ""
    var createdAt: Date = Date()

    // Archive
    var isArchived: Bool = false

    // Schedule (persisted as Data)
    // CloudKit wanted a default here too
    var scheduleData: Data = Data()

    // Logs
    // CloudKit: relationships must be optional
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]? = []

    // Reminders
    var reminderEnabled: Bool = false
    var reminderHour: Int?
    var reminderMinute: Int?

    // Per-habit icon (SF Symbol name)
    var iconName: String = "checkmark.circle"

    // manual ordering within “today”
    var sortOrder: Int = 9_999

    init(
        id: String = UUID().uuidString,
        title: String,
        createdAt: Date = Date(),
        isArchived: Bool = false,
        schedule: HabitSchedule = .daily,
        reminderEnabled: Bool = false,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        iconName: String = "checkmark.circle",
        sortOrder: Int = 9_999
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.scheduleData = (try? JSONEncoder().encode(schedule)) ?? Data()
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.iconName = iconName
        self.sortOrder = sortOrder
    }
}

// MARK: - Computed helpers

extension Habit {
    private static let scheduleEncoder = JSONEncoder()
    private static let scheduleDecoder = JSONDecoder()

    var schedule: HabitSchedule {
        get {
            (try? Habit.scheduleDecoder.decode(HabitSchedule.self, from: scheduleData)) ?? .daily
        }
        set {
            if let data = try? Habit.scheduleEncoder.encode(newValue) {
                scheduleData = data
            }
        }
    }

    var reminderTimeComponents: DateComponents? {
        guard reminderEnabled,
              let h = reminderHour,
              let m = reminderMinute
        else {
            return nil
        }

        var dc = DateComponents()
        dc.hour = h
        dc.minute = m
        return dc
    }

    var hasValidReminder: Bool {
        reminderEnabled && reminderHour != nil && reminderMinute != nil
    }

    func setReminderTime(from date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        reminderHour = comps.hour
        reminderMinute = comps.minute
    }
}
