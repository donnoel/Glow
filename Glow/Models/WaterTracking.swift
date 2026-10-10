import Foundation
import SwiftData

/// Independent of HabitLog: adding a drink never changes habit completion scores.
@Model
final class WaterEntry {
    var id: String = UUID().uuidString
    var timestamp: Date = Date()
    var dayKey: String = ""
    var milliliters: Double = 0

    init(milliliters: Double, timestamp: Date = .now, calendar: Calendar = .current) {
        self.milliliters = milliliters
        self.timestamp = timestamp
        self.dayKey = WaterAnalytics.dayKey(timestamp, calendar: calendar)
    }
}

/// A day's first saved goal remains intact even if all its drinks are deleted.
@Model
final class WaterDayGoal {
    var id: String = UUID().uuidString
    var dayKey: String = ""
    var createdAt: Date = Date()
    var milliliters: Double = 2_957.35295625

    init(dayKey: String, milliliters: Double, createdAt: Date = .now) {
        self.dayKey = dayKey
        self.milliliters = milliliters
        self.createdAt = createdAt
    }
}

/// All stored properties have defaults and no uniqueness constraints for CloudKit.
@Model
final class WaterPreferences {
    var id: String = UUID().uuidString
    var updatedAt: Date = Date()
    var profileRaw: String = "male"
    var unitRaw: String = "ounces"
    var goalMilliliters: Double = 2_957.35295625
    var presetsData: Data = Data()

    init() {}

    var profile: WaterGoalProfile { WaterGoalProfile(rawValue: profileRaw) ?? .custom }
    var unit: WaterUnit { WaterUnit(rawValue: unitRaw) ?? .ounces }
    var presets: [Double] {
        // New saves use a keyed payload so explicitly choosing 32 oz remains
        // possible after upgrading the original fourth preset to 24 oz.
        if let payload = try? JSONDecoder().decode([String: [Double]].self, from: presetsData),
           let values = payload["amounts"], values.count == 4,
           values.allSatisfy(WaterUnit.isValidAmount) {
            return values
        }
        guard let values = try? JSONDecoder().decode([Double].self, from: presetsData),
              values.count == 4, values.allSatisfy(WaterUnit.isValidAmount) else {
            return WaterUnit.defaultPresets
        }
        var upgraded = values
        if abs(values[3] - WaterUnit.ounces.milliliters(from: 32)) < 0.001 {
            upgraded[3] = WaterUnit.defaultPresets[3]
        }
        return upgraded
    }
}
