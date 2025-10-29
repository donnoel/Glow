import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: String
    var title: String
    var createdAt: Date

    // NEW: archive flag
    var isArchived: Bool

    // NEW: schedule (backed by Data for SwiftData)
    var scheduleData: Data

    // Existing logs relationship (for today toggles)
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog] = []

    init(
        id: String = UUID().uuidString,
        title: String,
        createdAt: Date = .now,
        isArchived: Bool = false,
        schedule: HabitSchedule = .daily
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.scheduleData = (try? JSONEncoder().encode(schedule)) ?? Data()
    }
}

extension Habit {
    var schedule: HabitSchedule {
        get { (try? JSONDecoder().decode(HabitSchedule.self, from: scheduleData)) ?? .daily }
        set { scheduleData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
