import Foundation
import SwiftData
import Testing
@testable import Glow

@MainActor
struct WaterTrackingTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }

    private func date(_ day: Int, month: Int = 10, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func container() throws -> ModelContainer {
        let schema = Schema([Habit.self, HabitLog.self, WaterEntry.self, WaterDayGoal.self, WaterPreferences.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }

    private func model() -> WaterTrackerViewModel {
        WaterTrackerViewModel(defaults: UserDefaults(suiteName: "WaterTests.\(UUID().uuidString)")!)
    }

    @Test func quantitiesUseUSFluidOuncesAndLocaleAwareStrictInput() throws {
        #expect(abs(WaterUnit.ounces.milliliters(from: 8) - 236.5882365) < 0.0001)
        #expect(WaterUnit.ounces.number(WaterUnit.defaultPresets[2]) == "21")
        #expect(WaterUnit.milliliters.parse("12,5", locale: Locale(identifier: "fr_FR")) == 12.5)
        for text in ["", "0", "-8", "12oops", "1e3", "NaN", "12.3.4", "1,000"] {
            #expect(WaterUnit.ounces.parse(text, locale: Locale(identifier: "en_US")) == nil)
        }
        let goal = WaterGoalProfile.male.suggestedMilliliters!
        let input = WaterUnit.milliliters.inputNumber(goal)
        #expect(WaterUnit.milliliters.parse(input) != nil, "Editable values must not include grouping separators")
    }

    @Test func repeatedDrinksUndoAndEditsDoNotTouchHabits() throws {
        let store = try container()
        let context = store.mainContext
        let habit = Habit(title: "Walk")
        context.insert(habit)
        let vm = model()
        #expect(vm.add(250, preferences: nil, goals: [], context: context, now: date(10), calendar: calendar))
        let goals = try context.fetch(FetchDescriptor<WaterDayGoal>())
        #expect(vm.add(500, preferences: nil, goals: goals, context: context, now: date(10, hour: 13), calendar: calendar))
        vm.undo(context: context)
        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.count == 1)
        let remaining = try #require(entries.first)
        #expect(remaining.milliliters == 250)
        #expect(vm.update(remaining, milliliters: 300, context: context))
        #expect(remaining.milliliters == 300)
        #expect(habit.logs?.isEmpty == true)
        #expect(try context.fetch(FetchDescriptor<HabitLog>()).isEmpty)
        vm.delete(remaining, context: context)
        #expect(try context.fetch(FetchDescriptor<WaterEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WaterDayGoal>()).count == 1)
    }

    @Test func savedGoalSurvivesSameDaySettingsChangeAndDeletion() throws {
        let store = try container()
        let context = store.mainContext
        let vm = model()
        #expect(vm.add(3_000, preferences: nil, goals: [], context: context, now: date(10), calendar: calendar))
        var draft = WaterSettingsDraft()
        draft.profile = .female
        draft.goalMilliliters = WaterGoalProfile.female.suggestedMilliliters!
        #expect(vm.saveSettings(draft, preferences: nil, context: context))
        let preferences = try context.fetch(FetchDescriptor<WaterPreferences>()).first
        let oldGoals = try context.fetch(FetchDescriptor<WaterDayGoal>())
        #expect(vm.add(100, preferences: preferences, goals: oldGoals, context: context, now: date(10, hour: 16), calendar: calendar))
        #expect(vm.add(2_250, preferences: preferences, goals: oldGoals, context: context, now: date(11), calendar: calendar))
        let goals = try context.fetch(FetchDescriptor<WaterDayGoal>())
        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        let report = WaterAnalytics.summaries(entries: entries.map { WaterEntryValue($0) }, goals: goals.map { WaterGoalValue($0) }, days: 2, now: date(11), calendar: calendar)
        #expect(report[0].goalMilliliters == WaterGoalProfile.male.suggestedMilliliters)
        #expect(report[1].goalMilliliters == WaterGoalProfile.female.suggestedMilliliters)
        #expect(report.allSatisfy { $0.reachedGoal })
        for entry in entries where entry.dayKey == report[0].id { vm.delete(entry, context: context) }
        #expect(vm.goal(for: report[0].id, goals: goals, preferences: preferences) == WaterGoalProfile.male.suggestedMilliliters)
    }

    @Test func missingDaysRemainUnknownAndAverageUsesLoggedDays() {
        let entry = WaterEntry(milliliters: 500, timestamp: date(10), calendar: calendar)
        let report = WaterAnalytics.summaries(entries: [WaterEntryValue(entry)], goals: [], days: 7, now: date(10), calendar: calendar)
        #expect(report.count == 7)
        #expect(report.filter(\.isLogged).count == 1)
        #expect(report.filter(\.reachedGoal).isEmpty)
        #expect(report.filter(\.isLogged).map(\.milliliters) == [500])
        #expect(report.dropLast().allSatisfy { $0.goalMilliliters == nil })
    }

    @Test func duplicateGoalSnapshotsResolveIdenticallyRegardlessOfInputOrder() {
        let key = WaterAnalytics.dayKey(date(10), calendar: calendar)
        let first = WaterDayGoal(dayKey: key, milliliters: 2_000, createdAt: date(10, hour: 8))
        let second = WaterDayGoal(dayKey: key, milliliters: 3_000, createdAt: date(10, hour: 9))
        let goals = [WaterGoalValue(second), WaterGoalValue(first)]
        let report = WaterAnalytics.summaries(entries: [], goals: goals, days: 1, now: date(10), calendar: calendar)
        let reversed = WaterAnalytics.summaries(entries: [], goals: goals.reversed(), days: 1, now: date(10), calendar: calendar)
        #expect(report[0].goalMilliliters == 2_000)
        #expect(reversed[0].goalMilliliters == 2_000)
        #expect(model().goal(for: key, goals: [second, first], preferences: nil) == 2_000)
    }

    @Test func civilDaysRemainStableAcrossMidnightAndDaylightSaving() {
        let before = WaterEntry(milliliters: 250, timestamp: date(7, month: 3, hour: 23), calendar: calendar)
        let after = WaterEntry(milliliters: 500, timestamp: date(8, month: 3, hour: 3), calendar: calendar)
        let report = WaterAnalytics.summaries(entries: [before, after].map { WaterEntryValue($0) }, goals: [], days: 3, now: date(9, month: 3), calendar: calendar)
        #expect(report.map(\.id) == ["2026-03-07", "2026-03-08", "2026-03-09"])
        #expect(report.map(\.milliliters) == [250, 500, 0])
        #expect(report[2].date.timeIntervalSince(report[1].date) == 23 * 60 * 60)
    }

    @Test func lastAmountPersistsAcrossViewModelRecreation() throws {
        let store = try container()
        let suiteName = "WaterPersistence.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vm = WaterTrackerViewModel(defaults: defaults)
        #expect(vm.add(621.0441208125, preferences: nil, goals: [], context: store.mainContext))
        #expect(WaterTrackerViewModel(defaults: defaults).lastAmount == 621.0441208125)
    }

    @Test func invalidWritesAreRejectedWithoutSaving() throws {
        let store = try container()
        let vm = model()
        #expect(!vm.add(.infinity, preferences: nil, goals: [], context: store.mainContext))
        var draft = WaterSettingsDraft()
        draft.presets = [250, -1, 500, 750]
        #expect(!vm.saveSettings(draft, preferences: nil, context: store.mainContext))
        #expect(try store.mainContext.fetch(FetchDescriptor<WaterEntry>()).isEmpty)
        #expect(try store.mainContext.fetch(FetchDescriptor<WaterPreferences>()).isEmpty)
    }

    @Test func additiveSchemaRetainsExistingHabitsAndColdLoadsWaterSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("GlowWaterMigration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Glow.store")
        try autoreleasepool {
            let schema = Schema([Habit.self, HabitLog.self])
            let config = ModelConfiguration("MigrationTest", schema: schema, url: url, cloudKitDatabase: .none)
            let legacy = try ModelContainer(for: schema, configurations: [config])
            let habit = Habit(title: "Existing walk")
            legacy.mainContext.insert(habit)
            legacy.mainContext.insert(HabitLog(completed: true, habit: habit))
            try legacy.mainContext.save()
        }
        try autoreleasepool {
            let schema = Schema([Habit.self, HabitLog.self, WaterEntry.self, WaterDayGoal.self, WaterPreferences.self])
            let config = ModelConfiguration("MigrationTest", schema: schema, url: url, cloudKitDatabase: .none)
            let upgraded = try ModelContainer(for: schema, configurations: [config])
            #expect(try upgraded.mainContext.fetch(FetchDescriptor<Habit>()).first?.title == "Existing walk")
            #expect(try upgraded.mainContext.fetch(FetchDescriptor<HabitLog>()).first?.completed == true)
            let vm = model()
            var draft = WaterSettingsDraft()
            draft.profile = .female
            draft.unit = .milliliters
            draft.goalMilliliters = 2_200
            draft.presets = [250, 350, 500, 750]
            #expect(vm.saveSettings(draft, preferences: nil, context: upgraded.mainContext))
            #expect(vm.add(500, preferences: nil, goals: [], context: upgraded.mainContext))
        }
        let schema = Schema([Habit.self, HabitLog.self, WaterEntry.self, WaterDayGoal.self, WaterPreferences.self])
        let reloaded = try ModelContainer(for: schema, configurations: [ModelConfiguration("MigrationTest", schema: schema, url: url, cloudKitDatabase: .none)])
        let settings = try #require(reloaded.mainContext.fetch(FetchDescriptor<WaterPreferences>()).first)
        #expect(settings.profile == .female)
        #expect(settings.unit == .milliliters)
        #expect(settings.goalMilliliters == 2_200)
        #expect(settings.presets == [250, 350, 500, 750])
        #expect(try reloaded.mainContext.fetch(FetchDescriptor<WaterEntry>()).first?.milliliters == 500)
    }
}
