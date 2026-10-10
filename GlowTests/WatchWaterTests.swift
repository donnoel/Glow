import Foundation
import SwiftData
import Testing
@testable import Glow

@MainActor
struct WatchWaterTests {
    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var eight: Double { WaterUnit.ounces.milliliters(from: 8) }

    private func snapshot(at date: Date, entries: [GlowWatchWaterEntry] = [],
                          receipts: [GlowWatchWaterReceipt] = [], goalOunces: Double = 50) -> GlowWatchSnapshot {
        GlowWatchSnapshot(generatedAt: date, day: GlowWatchDay(date: date), habits: [], receipts: [],
            water: GlowWatchWaterSnapshot(day: .waterDay(date: date), entries: entries,
                goalMilliliters: WaterUnit.ounces.milliliters(from: goalOunces),
                nextGoalMilliliters: WaterUnit.ounces.milliliters(from: 75), receipts: receipts))
    }

    private func container() throws -> ModelContainer {
        let schema = Schema([Habit.self, HabitLog.self, WaterEntry.self, WaterDayGoal.self, WaterPreferences.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }

    @Test func repeatedDrinksAddUpAndPartialAcknowledgementDoesNotDoubleCount() {
        var state = GlowWatchState()
        state.receive(snapshot(at: today))
        for amount in [8.0, 21, 24] { state.addWater(WaterUnit.ounces.milliliters(from: amount), at: today) }
        let commands = state.pendingWater
        #expect(commands.count == 3)
        #expect(Set(commands.map(\.entryID)).count == 3)
        state.receive(snapshot(at: today.addingTimeInterval(1),
            entries: [GlowWatchWaterEntry(id: commands[0].entryID, milliliters: eight)],
            receipts: [GlowWatchWaterReceipt(command: commands[0], rejection: nil)]))
        #expect(state.pendingWater.count == 2)
        let total = state.waterTotal(on: .waterDay(date: today))
        #expect(abs(WaterUnit.ounces.value(from: total) - 53) < 0.001)
        #expect(total >= state.waterGoal(on: .waterDay(date: today))!)
    }

    @Test func undoBeforeAddAcknowledgementAndRolloverKeepOriginalDay() {
        var state = GlowWatchState()
        state.receive(snapshot(at: today))
        state.addWater(eight, at: today)
        let added = state.pendingWater[0]
        state.undoWater(on: added.day)
        state.receive(snapshot(at: today.addingTimeInterval(1),
            entries: [GlowWatchWaterEntry(id: added.entryID, milliliters: eight)],
            receipts: [GlowWatchWaterReceipt(command: added, rejection: nil)]))
        #expect(state.pendingWater.count == 1)
        #expect(state.pendingWater[0].isDeleted)
        #expect(state.waterTotal(on: added.day) == 0)
        #expect(state.lastWaterEntry == nil)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        #expect(state.waterTotal(on: .waterDay(date: tomorrow)) == 0)
        #expect(state.waterGoal(on: .waterDay(date: tomorrow)) == WaterUnit.ounces.milliliters(from: 75))
    }

    @Test func localDrinksAndUndoSurviveRelaunch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("state.json")
        let first = GlowWatchStore(url: url)
        _ = try await first.receive(snapshot(at: today))
        let added = try await first.addWater(eight, at: today)
        let second = GlowWatchStore(url: url)
        let restored = try await second.load()
        #expect(restored.pendingWater == added.pendingWater)
        #expect(restored.lastWaterEntry == added.lastWaterEntry)
        _ = try await second.undoWater(on: .waterDay(date: today))
        let third = GlowWatchStore(url: url)
        let undone = try await third.load()
        #expect(undone.pendingWater.count == 1)
        #expect(undone.pendingWater[0].isDeleted)
        #expect(undone.waterTotal(on: .waterDay(date: today)) == 0)
    }

    @Test func oldHabitCacheUpgradesWithoutLosingPendingCheckIns() throws {
        var state = GlowWatchState()
        state.receive(snapshot(at: today))
        state.setCompleted(true, habitID: "read", day: GlowWatchDay(date: today))
        var oldJSON = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        oldJSON.removeValue(forKey: "pendingWater")
        oldJSON.removeValue(forKey: "lastWaterEntry")
        var oldSnapshot = try #require(oldJSON["snapshot"] as? [String: Any])
        oldSnapshot.removeValue(forKey: "water")
        oldJSON["snapshot"] = oldSnapshot
        let restored = try JSONDecoder().decode(GlowWatchState.self, from: JSONSerialization.data(withJSONObject: oldJSON))
        #expect(restored.pending == state.pending)
        #expect(restored.clientID == state.clientID)
        #expect(restored.pendingWater.isEmpty)
        #expect(restored.snapshot?.water == nil)
    }

    @Test func phoneReplayKeepsOneDrinkOriginalDayAndHistoricalGoal() throws {
        let store = try container()
        let context = store.mainContext
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        var state = GlowWatchState()
        state.receive(snapshot(at: yesterday))
        state.addWater(eight, at: yesterday)
        let command = state.pendingWater[0]
        #expect(try WatchWaterAction.apply(command, in: context) == nil)
        #expect(try WatchWaterAction.apply(command, in: context) == nil)
        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].dayKey == command.day.waterDayKey)
        #expect(entries[0].timestamp == yesterday)
        let goals = try context.fetch(FetchDescriptor<WaterDayGoal>())
        #expect(goals.count == 1)
        #expect(goals[0].milliliters == command.goalMilliliters)
        state.undoWater(on: command.day)
        #expect(try WatchWaterAction.apply(state.pendingWater[0], in: context) == nil)
        #expect(try context.fetch(FetchDescriptor<WaterEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WaterDayGoal>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<HabitLog>()).isEmpty)
    }

    @Test func savedGoalWinsAndPhoneEntriesAppearOnWatch() throws {
        let store = try container()
        let context = store.mainContext
        let key = GlowWatchDay.waterDay(date: today).waterDayKey
        context.insert(WaterDayGoal(dayKey: key, milliliters: eight, createdAt: today))
        let preferences = WaterPreferences()
        preferences.goalMilliliters = WaterUnit.ounces.milliliters(from: 100)
        context.insert(preferences)
        let entry = WaterEntry(milliliters: eight, timestamp: today)
        context.insert(entry)
        try context.save()
        let water = try WatchWaterAction.snapshot(in: context)
        #expect(water.goalMilliliters == eight)
        #expect(water.nextGoalMilliliters == preferences.goalMilliliters)
        #expect(water.entries.count == 1)
        #expect(water.entries[0].id.uuidString == entry.id)
        var state = GlowWatchState()
        state.receive(GlowWatchSnapshot(generatedAt: .now, day: GlowWatchDay(date: today), habits: [], receipts: [], water: water))
        #expect(state.waterTotal(on: water.day) == eight)
    }

    @Test func undoDeliveredFirstStillSavesOriginalGoal() throws {
        let store = try container()
        var state = GlowWatchState()
        state.receive(snapshot(at: today))
        state.addWater(eight, at: today)
        state.undoWater(on: .waterDay(date: today))
        let undo = state.pendingWater[0]
        #expect(try WatchWaterAction.apply(undo, in: store.mainContext) == nil)
        #expect(try store.mainContext.fetch(FetchDescriptor<WaterEntry>()).isEmpty)
        let goals = try store.mainContext.fetch(FetchDescriptor<WaterDayGoal>())
        #expect(goals.count == 1)
        #expect(goals[0].milliliters == undo.goalMilliliters)
    }

    @Test func invalidWaterAndRejectedDrinksNeverPersist() throws {
        let store = try container()
        let command = GlowWatchWaterCommand(id: UUID(), clientID: UUID(), sequence: 1, entryID: UUID(),
            day: .waterDay(date: today), timestamp: today, milliliters: -1, goalMilliliters: eight, isDeleted: false)
        #expect(try WatchWaterAction.apply(command, in: store.mainContext) != nil)
        #expect(try store.mainContext.fetch(FetchDescriptor<WaterEntry>()).isEmpty)
        var state = GlowWatchState()
        state.receive(snapshot(at: today))
        state.addWater(eight, at: today)
        let pending = state.pendingWater[0]
        state.receive(snapshot(at: today, receipts: [GlowWatchWaterReceipt(command: pending, rejection: "Invalid date")]))
        #expect(state.pendingWater.isEmpty)
        #expect(state.waterTotal(on: pending.day) == 0)
        #expect(state.syncError == "Invalid date")
    }
}
