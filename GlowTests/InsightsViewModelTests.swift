import Foundation
import Testing
@testable import Glow

@MainActor
struct InsightsViewModelTests {
    private var calendar: Calendar { .current }

    private var today: Date {
        calendar.startOfDay(for: .now)
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }

    private func makeHabit(
        title: String,
        schedule: HabitSchedule,
        isArchived: Bool = false
    ) -> Habit {
        Habit(
            title: title,
            createdAt: day(-30),
            isArchived: isArchived,
            schedule: schedule,
            sortOrder: 0
        )
    }

    private func complete(_ dates: [Date], for habit: Habit) {
        habit.logs = dates.map { HabitLog(date: $0, completed: true, habit: habit) }
    }

    @Test
    func scheduleAwareCompletionUsesOnlyScheduledOpportunities() throws {
        let scheduledOffsets = [-6, -4, -2]
        let weekdays = Set(scheduledOffsets.map { Weekday.from(day($0), calendar: calendar) })
        let habit = makeHabit(
            title: "Three times",
            schedule: HabitSchedule(kind: .custom, days: weekdays)
        )

        complete(
            [day(-6), day(-2), day(-13), day(-11), day(-9)],
            for: habit
        )

        let model = InsightsViewModel(habits: [habit], now: today, calendar: calendar)
        let rhythm = try #require(model.habitRhythms.first)

        #expect(rhythm.completedScheduled == 2)
        #expect(rhythm.scheduled == 3)
        #expect(rhythm.completionPercent == 67)
        #expect(rhythm.previousCompletedScheduled == 3)
        #expect(rhythm.previousScheduled == 3)
        #expect(rhythm.percentagePointChange == -33)
        #expect(model.completedScheduled == 2)
        #expect(model.scheduled == 3)
    }

    @Test
    func bonusCheckInIsVisibleButExcludedFromScheduledRate() throws {
        let todayWeekday = Weekday.from(today, calendar: calendar)
        let habit = makeHabit(
            title: "Weekly",
            schedule: HabitSchedule(kind: .custom, days: [todayWeekday])
        )
        complete([day(-1), today], for: habit)

        let model = InsightsViewModel(habits: [habit], now: today, calendar: calendar)
        let rhythm = try #require(model.habitRhythms.first)

        #expect(rhythm.completedScheduled == 1)
        #expect(rhythm.scheduled == 1)
        #expect(rhythm.bonusCompletions == 1)
        #expect(rhythm.dayStates[5] == .bonus)
        #expect(rhythm.dayStates[6] == .completed)
        #expect(model.completionPercent == 100)
        #expect(model.activeDays == 2)
    }

    @Test
    func datesBeforeHabitCreationAreNotCountedAsMissed() throws {
        let habit = Habit(
            title: "New habit",
            createdAt: day(-2),
            schedule: .daily,
            sortOrder: 0
        )
        complete([day(-1)], for: habit)

        let model = InsightsViewModel(habits: [habit], now: today, calendar: calendar)
        let rhythm = try #require(model.habitRhythms.first)

        #expect(rhythm.scheduled == 3)
        #expect(rhythm.completedScheduled == 1)
        #expect(rhythm.dayStates.prefix(4).allSatisfy { $0 == .notScheduled })
        #expect(rhythm.openPastDays == 1)
    }

    @Test
    func archivedHabitsAreExcludedFromInsightsAndLifetimeTotals() {
        let active = makeHabit(title: "Active", schedule: .daily)
        let archived = makeHabit(title: "Archived", schedule: .daily, isArchived: true)
        complete([today], for: active)
        complete([today, day(-1)], for: archived)

        let model = InsightsViewModel(
            habits: [active, archived],
            now: today,
            calendar: calendar
        )

        #expect(model.habitRhythms.map(\.habit.title) == ["Active"])
        #expect(model.lifetimeCompletions == 1)
        #expect(model.lifetimeActiveDays == 1)
    }
}
