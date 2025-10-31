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

    // Reminders
    var reminderEnabled: Bool
    var reminderHour: Int?
    var reminderMinute: Int?

    // Per-habit icon (SF Symbol name)
    // e.g. "wineglass", "drop.fill", "dumbbell.fill", etc.
    var iconName: String

    // NEW (M11-ish): manual ordering within “today”
    // Lower = shows higher in the list.
    var sortOrder: Int

    init(
        id: String = UUID().uuidString,
        title: String,
        createdAt: Date = .now,
        isArchived: Bool = false,
        schedule: HabitSchedule = .daily,
        reminderEnabled: Bool = false,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        iconName: String = "checkmark.circle", // fallback if we can't guess
        sortOrder: Int = 9_999                   // new habits drop to bottom by default
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
    var schedule: HabitSchedule {
        get {
            (try? JSONDecoder().decode(HabitSchedule.self, from: scheduleData)) ?? .daily
        }
        set {
            scheduleData = (try? JSONEncoder().encode(newValue)) ?? Data()
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

    func setReminderTime(from date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        reminderHour = comps.hour
        reminderMinute = comps.minute
    }
}

// MARK: - Icon helper

extension Habit {
    /// Pick a default SF Symbol for a given title (“drink water” -> drop.fill).
    /// Used when creating a brand new habit in HomeView.
    static func guessIconName(for title: String) -> String {
        HabitIconLibrary.guessIcon(for: title)
    }
}
