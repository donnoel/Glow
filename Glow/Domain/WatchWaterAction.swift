import Foundation
import SwiftData

/// Reuses the existing water models; durable retries address the same entry ID.
enum WatchWaterAction {
    static func apply(_ command: GlowWatchWaterCommand, in context: ModelContext, now: Date = .now) throws -> String? {
        guard let date = command.day.waterDate(),
              date <= Calendar.current.startOfDay(for: now),
              command.timestamp.timeIntervalSince1970.isFinite,
              command.timestamp <= now.addingTimeInterval(300),
              WaterUnit.isValidAmount(command.milliliters),
              WaterUnit.isValidAmount(command.goalMilliliters) else {
            return "This drink has an invalid amount or date. Please check your Watch clock."
        }
        let id = command.entryID.uuidString
        let key = command.day.waterDayKey
        let entries = try context.fetch(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.id == id }))
        let goals = try context.fetch(FetchDescriptor<WaterDayGoal>(predicate: #Predicate { $0.dayKey == key }))
        if goals.isEmpty {
            // Undo can reach the phone before Add; preserve the first locally logged goal.
            context.insert(WaterDayGoal(dayKey: key, milliliters: command.goalMilliliters, createdAt: command.timestamp))
        }
        if command.isDeleted {
            for entry in entries { context.delete(entry) }
        } else if entries.isEmpty {
            let entry = WaterEntry(milliliters: command.milliliters, timestamp: command.timestamp)
            entry.id = id
            entry.dayKey = key
            context.insert(entry)
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
        return nil
    }

    static func snapshot(in context: ModelContext, now: Date = .now,
                         receipts: [GlowWatchWaterReceipt] = []) throws -> GlowWatchWaterSnapshot {
        let day = GlowWatchDay.waterDay(date: now)
        let key = day.waterDayKey
        let entries = try context.fetch(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.dayKey == key }))
        let goals = try context.fetch(FetchDescriptor<WaterDayGoal>(predicate: #Predicate { $0.dayKey == key }))
        let preferences = try context.fetch(FetchDescriptor<WaterPreferences>(sortBy: [
            SortDescriptor(\WaterPreferences.updatedAt, order: .reverse), SortDescriptor(\WaterPreferences.id)
        ])).first
        let model = WaterTrackerViewModel()
        return GlowWatchWaterSnapshot(
            day: day,
            entries: entries.compactMap { entry in
                guard let id = UUID(uuidString: entry.id), WaterUnit.isValidAmount(entry.milliliters) else { return nil }
                return GlowWatchWaterEntry(id: id, milliliters: entry.milliliters, timestamp: entry.timestamp)
            },
            goalMilliliters: model.goal(for: key, goals: goals, preferences: preferences),
            nextGoalMilliliters: preferences?.goalMilliliters ?? WaterGoalProfile.male.suggestedMilliliters!,
            receipts: receipts,
            nudges: preferences?.nudgeSettings ?? WaterNudgeSettings(),
            unitRaw: preferences?.unit.rawValue ?? WaterUnit.ounces.rawValue
        )
    }
}
