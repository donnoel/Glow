import Testing
@testable import Glow
import SwiftData
import Foundation

@MainActor
struct ModelContextSaveTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Habit.self,
            HabitLog.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test
    func saveSafely_does_not_throw_on_clean_context() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // This should just be a no-op and not crash
        context.saveSafely()
        context.saveSafely()
    }

    @Test
    func saveSafely_can_save_a_new_habit() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let habit = Habit(
            title: "Test habit",
            createdAt: .now,
            isArchived: false,
            schedule: HabitSchedule(kind: .daily, days: []),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "checkmark.circle",
            sortOrder: 0
        )

        context.insert(habit)

        // should not crash, should attempt a save
        context.saveSafely()
    }

    @Test
    func saveSafely_persists_inserted_habit() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let habit = Habit(
            title: "Persisted habit",
            createdAt: .now,
            isArchived: false,
            schedule: HabitSchedule(kind: .daily, days: []),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "checkmark.circle",
            sortOrder: 0
        )

        context.insert(habit)
        context.saveSafely()

        let descriptor = FetchDescriptor<Habit>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Persisted habit")
    }
}
