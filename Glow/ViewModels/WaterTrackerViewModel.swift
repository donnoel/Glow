import Combine
import Foundation
import OSLog
import SwiftData

enum WaterTrackerSheet: String, Identifiable {
    case settings, history, custom
    var id: String { rawValue }
}

struct WaterSettingsDraft {
    var profile: WaterGoalProfile = .male
    var unit: WaterUnit = .ounces
    var goalMilliliters: Double = WaterGoalProfile.male.suggestedMilliliters!
    var presets: [Double] = WaterUnit.defaultPresets
    var nudges = WaterNudgeSettings()

    init(preferences: WaterPreferences? = nil) {
        guard let preferences else { return }
        profile = preferences.profile
        unit = preferences.unit
        goalMilliliters = preferences.goalMilliliters
        presets = preferences.presets
        nudges = preferences.nudgeSettings
    }
}

@MainActor
final class WaterTrackerViewModel: ObservableObject {
    @Published var sheet: WaterTrackerSheet?
    @Published var errorMessage: String?
    @Published private(set) var undoEntryID: String?
    @Published private(set) var undoDayKey: String?
    @Published private(set) var lastAmount: Double

    private let defaults: UserDefaults
    private static let lastAmountKey = "water.lastAmountMilliliters"
    private let logger = Logger(subsystem: "movie.Glow", category: "WaterTracking")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastAmount = defaults.double(forKey: Self.lastAmountKey)
    }

    func goal(for key: String, goals: [WaterDayGoal], preferences: WaterPreferences?) -> Double {
        let saved = goals.filter { $0.dayKey == key }.min {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
        }
        return saved?.milliliters ?? preferences?.goalMilliliters ?? WaterGoalProfile.male.suggestedMilliliters!
    }

    @discardableResult
    func add(_ milliliters: Double, preferences: WaterPreferences?, goals: [WaterDayGoal],
             context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard WaterUnit.isValidAmount(milliliters) else { return false }
        let key = WaterAnalytics.dayKey(now, calendar: calendar)
        if !goals.contains(where: { $0.dayKey == key }) {
            context.insert(WaterDayGoal(dayKey: key,
                                       milliliters: goal(for: key, goals: goals, preferences: preferences),
                                       createdAt: now))
        }
        let entry = WaterEntry(milliliters: milliliters, timestamp: now, calendar: calendar)
        context.insert(entry)
        guard save(context) else { return false }
        undoEntryID = entry.id
        undoDayKey = key
        lastAmount = milliliters
        defaults.set(milliliters, forKey: Self.lastAmountKey)
        return true
    }

    func undo(context: ModelContext) {
        guard let id = undoEntryID else { return }
        do {
            let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.id == id })
            if let entry = try context.fetch(descriptor).first {
                context.delete(entry)
                guard save(context) else { return }
            }
            undoEntryID = nil
            undoDayKey = nil
        } catch {
            report(error)
        }
    }

    @discardableResult
    func update(_ entry: WaterEntry, milliliters: Double, context: ModelContext) -> Bool {
        guard WaterUnit.isValidAmount(milliliters) else { return false }
        entry.milliliters = milliliters
        return save(context)
    }

    func delete(_ entry: WaterEntry, context: ModelContext) {
        let id = entry.id
        context.delete(entry)
        if save(context), undoEntryID == id { undoEntryID = nil }
    }

    @discardableResult
    func saveSettings(_ draft: WaterSettingsDraft, preferences: WaterPreferences?,
                      context: ModelContext, now: Date = .now) -> Bool {
        guard WaterUnit.isValidAmount(draft.goalMilliliters), draft.presets.count == 4,
              draft.presets.allSatisfy(WaterUnit.isValidAmount),
              !draft.nudges.isEnabled || draft.nudges.isValid else { return false }
        do {
            let data = try JSONEncoder().encode(WaterPreferencesPayload(amounts: draft.presets, nudges: draft.nudges))
            let settings = preferences ?? WaterPreferences()
            if preferences == nil { context.insert(settings) }
            settings.profileRaw = draft.profile.rawValue
            settings.unitRaw = draft.unit.rawValue
            settings.goalMilliliters = draft.goalMilliliters
            settings.presetsData = data
            settings.updatedAt = now
            return save(context)
        } catch {
            report(error)
            return false
        }
    }

    private func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            report(error)
            return false
        }
    }

    private func report(_ error: Error) {
        logger.error("Water data save failed: \(error.localizedDescription, privacy: .public)")
        errorMessage = "Your change couldn’t be saved. Please try again."
    }
}
