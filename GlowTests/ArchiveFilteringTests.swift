import Testing
@testable import Glow
import Foundation

@MainActor
struct ArchiveFilteringTests {

    private func dailySchedule() -> HabitSchedule {
        HabitSchedule(kind: .daily, days: [])
    }

    private func makeHabit(
        title: String,
        isArchived: Bool,
        sortOrder: Int
    ) -> Habit {
        Habit(
            title: title,
            createdAt: .now,
            isArchived: isArchived,
            schedule: dailySchedule(),
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "checkmark.circle",
            sortOrder: sortOrder
        )
    }

    /// This mirrors what ArchiveView conceptually does.
    private func archivedHabits(from habits: [Habit]) -> [Habit] {
        habits
            .filter { $0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    @Test
    func filters_only_archived_habits() throws {
        let a = makeHabit(title: "Archived A", isArchived: true, sortOrder: 0)
        let b = makeHabit(title: "Active B", isArchived: false, sortOrder: 1)
        let c = makeHabit(title: "Archived C", isArchived: true, sortOrder: 2)

        let result = archivedHabits(from: [a, b, c])

        #expect(result.count == 2)
        #expect(result.map(\.title).sorted() == ["Archived A", "Archived C"].sorted())
    }

    @Test
    func sorts_by_sortOrder() throws {
        let a = makeHabit(title: "First", isArchived: true, sortOrder: 0)
        let b = makeHabit(title: "Third", isArchived: true, sortOrder: 2)
        let c = makeHabit(title: "Second", isArchived: true, sortOrder: 1)

        let result = archivedHabits(from: [a, b, c])

        #expect(result.map(\.title) == ["First", "Second", "Third"])
    }
}
