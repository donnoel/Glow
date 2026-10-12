import Foundation
import Testing
@testable import Glow

nonisolated struct WaterNudgePlannerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func date(day: Int = 11, month: Int = 10, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func input(total: Double = 0, goal: Double = 100, now: Date,
                       lastDrink: Date? = nil, unit: WaterUnit = .ounces) -> WaterNudgeInput {
        WaterNudgeInput(day: GlowWatchDay(date: now, calendar: calendar),
            totalMilliliters: unit.milliliters(from: total), goalMilliliters: unit.milliliters(from: goal),
            lastDrinkAt: lastDrink, unit: unit)
    }

    private let enabled = WaterNudgeSettings(isEnabled: true)

    @Test func emptyDayHasThreeSeparatedGentleOpportunities() {
        let now = date(hour: 8)
        let items = WaterNudgePlanner.plan(input: input(now: now), settings: enabled, now: now, calendar: calendar)
        #expect(items.map(\.fireDate) == [date(hour: 11, minute: 54), date(hour: 15, minute: 9), date(hour: 18, minute: 24)])
        #expect(Set(items.map(\.identifier)).count == 3)
        #expect(Set(items.map(\.title)).count == 3)
        #expect(items.allSatisfy { $0.body.contains("If you haven’t logged more") && $0.body.contains("100 fl oz") })
        #expect(items.allSatisfy { $0.fireDate <= date(hour: 20) })
        for pair in zip(items, items.dropFirst()) {
            #expect(pair.1.fireDate.timeIntervalSince(pair.0.fireDate) >= 3 * 60 * 60)
        }
    }

    @Test func progressDefersUntilBehindPaceAndChangesRemainingAmount() {
        let now = date(hour: 12)
        let items = WaterNudgePlanner.plan(input: input(total: 40, now: now), settings: enabled, now: now, calendar: calendar)
        #expect(items.first?.fireDate == date(hour: 14, minute: 30))
        #expect(items.map(\.fireDate) == [date(hour: 14, minute: 30), date(hour: 17, minute: 30)])
        #expect(items.allSatisfy { $0.body.contains("60 fl oz") })
        let nearGoal = WaterNudgePlanner.plan(input: input(total: 90, now: now), settings: enabled, now: now, calendar: calendar)
        #expect(nearGoal.isEmpty)
    }

    @Test func reachedGoalDisabledAndInvalidInputProduceNoPlan() {
        let now = date(hour: 8)
        #expect(WaterNudgePlanner.plan(input: input(total: 100, now: now), settings: enabled, now: now, calendar: calendar).isEmpty)
        #expect(WaterNudgePlanner.plan(input: input(total: 101, now: now), settings: enabled, now: now, calendar: calendar).isEmpty)
        #expect(WaterNudgePlanner.plan(input: input(now: now), settings: WaterNudgeSettings(), now: now, calendar: calendar).isEmpty)
        for value in [Double.nan, .infinity, -1] {
            let invalid = WaterNudgeInput(day: GlowWatchDay(date: now, calendar: calendar),
                totalMilliliters: value, goalMilliliters: 2_000, lastDrinkAt: nil, unit: .milliliters)
            #expect(WaterNudgePlanner.plan(input: invalid, settings: enabled, now: now, calendar: calendar).isEmpty)
        }
        #expect(WaterNudgePlanner.plan(input: input(goal: 0, now: now), settings: enabled, now: now, calendar: calendar).isEmpty)
    }

    @Test func lateStartSkipsMissedOpportunitiesWithoutCatchUp() {
        let early = date(hour: 8)
        let original = WaterNudgePlanner.plan(input: input(now: early), settings: enabled, now: early, calendar: calendar)
        let now = date(hour: 16)
        let remaining = WaterNudgePlanner.plan(input: input(now: now), settings: enabled, now: now, calendar: calendar)
        #expect(remaining.count == 1)
        #expect(remaining.first == original.last)
        let atFire = date(hour: 18, minute: 24)
        #expect(WaterNudgePlanner.plan(input: input(now: atFire), settings: enabled, now: atFire, calendar: calendar).isEmpty)
        let evening = date(hour: 21)
        #expect(WaterNudgePlanner.plan(input: input(now: evening), settings: enabled, now: evening, calendar: calendar).isEmpty)
    }

    @Test func recentDrinkAllowsNinetyMinutesAndRetainsSpacing() {
        let now = date(hour: 11, minute: 30)
        let items = WaterNudgePlanner.plan(input: input(total: 10, now: now, lastDrink: now), settings: enabled, now: now, calendar: calendar)
        #expect(items.map(\.fireDate) == [date(hour: 13), date(hour: 16), date(hour: 19)])
        #expect(items.first!.fireDate.timeIntervalSince(now) == 90 * 60)
        let previousDay = date(day: 10, hour: 23)
        let withOldDrink = WaterNudgePlanner.plan(input: input(now: now, lastDrink: previousDay), settings: enabled, now: now, calendar: calendar)
        #expect(withOldDrink.first?.fireDate == date(hour: 11, minute: 54))
    }

    @Test func unitChangesOnlyTheMessageAndUsesProvidedDailyGoal() {
        let now = date(hour: 8)
        let ounces = input(total: 25, goal: 100, now: now)
        let milliliters = WaterNudgeInput(day: ounces.day, totalMilliliters: ounces.totalMilliliters,
            goalMilliliters: ounces.goalMilliliters, lastDrinkAt: nil, unit: .milliliters)
        let imperial = WaterNudgePlanner.plan(input: ounces, settings: enabled, now: now, calendar: calendar)
        let metric = WaterNudgePlanner.plan(input: milliliters, settings: enabled, now: now, calendar: calendar)
        #expect(imperial.map(\.fireDate) == metric.map(\.fireDate))
        #expect(imperial.map(\.identifier) == metric.map(\.identifier))
        #expect(imperial.allSatisfy { $0.body.contains("75 fl oz") })
        #expect(metric.allSatisfy { $0.body.contains(WaterUnit.milliliters.label(ounces.goalMilliliters - ounces.totalMilliliters)) })
        #expect(!metric.contains { $0.body.contains("fl oz") })
    }

    @Test func settingsValidateQuietWindowAndShortWindowsRemainSpaced() throws {
        #expect(enabled.isValid)
        for settings in [WaterNudgeSettings(isEnabled: true, startHour: -1, endHour: 21),
                         WaterNudgeSettings(isEnabled: true, startHour: 8, endHour: 24),
                         WaterNudgeSettings(isEnabled: true, startHour: 21, endHour: 8),
                         WaterNudgeSettings(isEnabled: true, startHour: 8, endHour: 13)] {
            #expect(!settings.isValid)
            let now = date(hour: 8)
            #expect(WaterNudgePlanner.plan(input: input(now: now), settings: settings, now: now, calendar: calendar).isEmpty)
        }
        let short = WaterNudgeSettings(isEnabled: true, startHour: 8, endHour: 14)
        #expect(short.isValid)
        #expect(try JSONDecoder().decode(WaterNudgeSettings.self, from: JSONEncoder().encode(short)) == short)
        let now = date(hour: 8)
        let items = WaterNudgePlanner.plan(input: input(now: now), settings: short, now: now, calendar: calendar)
        #expect(items.count == 2)
        #expect(items.last!.fireDate.timeIntervalSince(items.first!.fireDate) >= 3 * 60 * 60)
        #expect(items.last!.fireDate <= date(hour: 13))
    }

    @Test func civilDayGuardPreventsStalePlansAcrossMidnightAndDaylightSaving() {
        let beforeMidnight = date(hour: 23)
        let oldInput = input(now: beforeMidnight)
        let tomorrow = date(day: 12, hour: 8)
        #expect(WaterNudgePlanner.plan(input: oldInput, settings: enabled, now: tomorrow, calendar: calendar).isEmpty)
        for day in [date(day: 8, month: 3, hour: 0), date(day: 1, month: 11, hour: 0)] {
            let settings = WaterNudgeSettings(isEnabled: true, startHour: 0, endHour: 8)
            let items = WaterNudgePlanner.plan(input: input(now: day), settings: settings, now: day, calendar: calendar)
            let end = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
            #expect(!items.isEmpty)
            #expect(items.count <= 3)
            #expect(items.allSatisfy { GlowWatchDay(date: $0.fireDate, calendar: calendar) == GlowWatchDay(date: day, calendar: calendar) })
            #expect(items.allSatisfy { $0.fireDate <= end.addingTimeInterval(-60 * 60) })
            for pair in zip(items, items.dropFirst()) {
                #expect(pair.1.fireDate.timeIntervalSince(pair.0.fireDate) >= 3 * 60 * 60)
            }
        }
    }
}
