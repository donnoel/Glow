import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: String
    var title: String
    var createdAt: Date

    // NEW: relationship to logs
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog] = []

    init(id: String = UUID().uuidString, title: String, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
