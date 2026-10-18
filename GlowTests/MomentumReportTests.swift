import Foundation
import Testing
@testable import Glow

@MainActor
struct MomentumReportTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func report(_ period: MomentumReportPeriod = .weekly, habits: [Habit] = [],
                        entries: [WaterEntry] = [], goals: [WaterDayGoal] = [],
                        now: Date? = nil, unit: WaterUnit = .milliliters,
                        scope: MomentumReportScope = .all) -> MomentumReport {
        MomentumReportBuilder.make(period: period, scope: scope, habits: habits, entries: entries.map(WaterEntryValue.init),
                                   goals: goals.map(WaterGoalValue.init), unit: unit,
                                   now: now ?? date(2025, 10, 18), calendar: calendar)
    }

    @Test func calendarPeriodsAndInclusiveToday() {
        let now = date(2025, 10, 18)
        let earliest = date(2024, 2, 29)
        let starts: [(MomentumReportPeriod, Date)] = [
            (.weekly, date(2025, 10, 12)), (.monthly, date(2025, 10, 1)),
            (.quarterly, date(2025, 10, 1)), (.annual, date(2025, 1, 1)),
            (.lifetime, earliest)
        ]
        for (period, expected) in starts {
            #expect(period.start(now: now, earliest: earliest, calendar: calendar) == calendar.startOfDay(for: expected))
        }
        #expect(report(.monthly).dayCount == 18)
        #expect(report(.quarterly, now: date(2025, 12, 31)).dayCount == 92)
        #expect(report(.annual, now: date(2024, 12, 31)).dayCount == 366)
        #expect(report(.quarterly, now: date(2025, 1, 1)).dayCount == 1)
    }

    @Test func weekAcrossDaylightSavingUsesCivilDays() {
        let result = report(now: date(2025, 3, 10))
        #expect(result.start == calendar.startOfDay(for: date(2025, 3, 4)))
        #expect(result.dayCount == 7)
        #expect(result.end.timeIntervalSince(result.start) == 6 * 86_400 - 3_600)
    }

    @Test func scheduleCreationDuplicatesAndArchivedFiltering() throws {
        let habit = Habit(title: "Read", createdAt: date(2025, 10, 15), schedule: .weekdays([.wed, .fri]))
        habit.logs = [
            HabitLog(date: date(2025, 10, 15), completed: true, habit: habit),
            HabitLog(date: date(2025, 10, 15), completed: true, habit: habit),
            HabitLog(date: date(2025, 10, 16), completed: true, habit: habit),
            HabitLog(date: date(2025, 10, 17), completed: false, habit: habit),
            HabitLog(date: date(2025, 10, 14), completed: true, habit: habit),
            HabitLog(date: date(2025, 10, 19), completed: true, habit: habit)
        ]
        let archived = Habit(title: "Archived", createdAt: date(2020, 1, 1), isArchived: true)
        archived.logs = [HabitLog(date: date(2025, 10, 18), completed: true, habit: archived)]
        let result = report(habits: [habit, archived], scope: .active)
        #expect(result.habits.count == 1)
        #expect(result.scheduled == 2)
        #expect(result.completed == 1)
        #expect(result.bonus == 1)
        #expect(result.completionPercent == 50)
        #expect(result.activeDays == 2)
        #expect(try #require(result.habits.first).title == "Read")
        #expect(!result.shareText.contains("Archived"))
        #expect(report(.lifetime, habits: [habit, archived], scope: .active).dayCount == 4)
    }

    @Test func allHabitsIncludesArchivedHistoryWithoutInventingMissedDays() {
        let active = Habit(title: "Read", createdAt: date(2025, 10, 18))
        active.logs = [HabitLog(date: date(2025, 10, 18), completed: true, habit: active)]
        let archived = Habit(title: "Run", createdAt: date(2024, 1, 1), isArchived: true)
        archived.logs = [17, 17].map { HabitLog(date: date(2025, 10, $0), completed: true, habit: archived) }
        let all = report(habits: [active, archived])
        #expect(all.scope == .all)
        #expect(all.habits.count == 2)
        #expect(all.totalCheckIns == 2)
        #expect(all.archivedCheckIns == 1)
        #expect(all.activeDays == 2)
        #expect(all.scheduled == 1)
        #expect(all.completed == 1)
        #expect(all.completionPercent == 100)
        #expect(all.shareText.contains("Run\n1 recorded check-ins · Archived"))
        let onlyArchived = report(habits: [archived])
        #expect(onlyArchived.totalCheckIns == 1)
        #expect(onlyArchived.completionPercent == nil)
        #expect(report(.lifetime, habits: [active, archived]).start == calendar.startOfDay(for: date(2024, 1, 1)))
        let activeOnly = report(habits: [active, archived], scope: .active)
        #expect(activeOnly.totalCheckIns == 1)
        #expect(activeOnly.activeDays == 1)
        #expect(!activeOnly.shareText.contains("Run"))
        archived.isArchived = false
        let resumed = report(habits: [active, archived], scope: .active)
        #expect(resumed.habits.count == 2)
        #expect(resumed.totalCheckIns == 2)
        #expect(resumed.notes.contains("Past schedule changes and pause/archive dates are not stored"))
    }

    @Test func activeDaysAreDistinctAcrossHabitsAndZeroScheduledIsNotZeroPercent() {
        let first = Habit(title: "Stretch", createdAt: date(2025, 10, 1), schedule: .weekdays([]))
        let second = Habit(title: "Walk", createdAt: date(2025, 10, 1), schedule: .weekdays([]))
        for habit in [first, second] {
            habit.logs = [HabitLog(date: date(2025, 10, 18), completed: true, habit: habit)]
        }
        let result = report(habits: [first, second])
        #expect(result.activeDays == 1)
        #expect(result.bonus == 2)
        #expect(result.completionPercent == nil)
        #expect(result.momentumText.contains("No scheduled check-ins"))
        #expect(!result.momentumText.contains("0%"))
    }

    @Test func weeklyTotalsMatchInsights() {
        let habit = Habit(title: "Read", createdAt: date(2025, 10, 1), schedule: .weekdays([.mon, .wed, .fri]))
        habit.logs = [13, 14, 17].map { HabitLog(date: date(2025, 10, $0), completed: true, habit: habit) }
        let insights = InsightsViewModel(habits: [habit], now: date(2025, 10, 18), calendar: calendar)
        let result = report(habits: [habit])
        #expect(result.completed == insights.completedScheduled)
        #expect(result.scheduled == insights.scheduled)
        #expect(result.activeDays == insights.activeDays)
        #expect(result.completionPercent == insights.completionPercent)
        #expect(result.bonus == insights.habitRhythms.reduce(0) { $0 + $1.bonusCompletions })
        #expect(result.shareText.contains(result.habits[0].detail))
    }

    @Test func hydrationUsesSavedGoalsAndLoggedDayAverageWithoutChangingMomentum() {
        let first = WaterEntry(milliliters: 500, timestamp: date(2025, 10, 17), calendar: calendar)
        let second = WaterEntry(milliliters: 250, timestamp: date(2025, 10, 18, hour: 8), calendar: calendar)
        let goal = WaterDayGoal(dayKey: first.dayKey, milliliters: 500, createdAt: date(2025, 10, 17))
        let duplicateGoal = WaterDayGoal(dayKey: first.dayKey, milliliters: 1_000, createdAt: date(2025, 10, 18))
        let deletedDayGoal = WaterDayGoal(dayKey: "2025-10-16", milliliters: 500)
        let invalid = WaterEntry(milliliters: .nan, timestamp: date(2025, 10, 18), calendar: calendar)
        let future = WaterEntry(milliliters: 100, timestamp: date(2025, 10, 18, hour: 20), calendar: calendar)
        let result = report(entries: [first, second, invalid, future], goals: [goal, duplicateGoal, deletedDayGoal])
        #expect(result.waterLoggedDays == 2)
        #expect(result.waterKnownGoalDays == 1)
        #expect(result.waterGoalDays == 1)
        #expect(result.waterTotal == 750)
        #expect(result.waterText.contains("375 mL average"))
        #expect(result.completed == 0)
        #expect(result.bonus == 0)
        #expect(result.activeDays == 0)
        #expect(result.completionPercent == nil)
        #expect(report(entries: [first], unit: .ounces).waterText.contains("fl oz"))
    }

    @Test func lifetimeIncludesWaterBeforeHabitsAndWindowExcludesOlderData() {
        let entry = WaterEntry(milliliters: 500, timestamp: date(2024, 2, 29), calendar: calendar)
        let habit = Habit(title: "Read", createdAt: date(2025, 10, 18))
        let result = report(.lifetime, habits: [habit], entries: [entry])
        #expect(result.start == calendar.startOfDay(for: date(2024, 2, 29)))
        #expect(result.scheduled == 1)
        #expect(result.waterTotal == 500)
        #expect(report(.annual, habits: [habit], entries: [entry]).waterLoggedDays == 0)
    }

    @Test func emptyReportAndSharedPreviewContent() {
        let empty = report(.lifetime)
        #expect(empty.dayCount == 1)
        #expect(empty.completionPercent == nil)
        #expect(empty.waterTotal == 0)
        #expect(!empty.shareText.contains("nan"))
        #expect(empty.shareText.contains(empty.dateRange))
        #expect(empty.shareText.contains(empty.momentumText))
        #expect(empty.shareText.contains(empty.waterText))
        #expect(empty.shareText.contains(empty.notes))
        for period in MomentumReportPeriod.allCases {
            #expect(report(period).shareText.contains("\(period.title) momentum"))
        }
    }
}
