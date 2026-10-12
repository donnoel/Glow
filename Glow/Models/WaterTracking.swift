import Foundation
import SwiftData

/// Keeps reminder preferences in the existing payload without changing the CloudKit schema.
nonisolated struct WaterPreferencesPayload: Codable, Sendable {
    let amounts: [Double]
    var nudges: WaterNudgeSettings? = nil

    init(amounts: [Double], nudges: WaterNudgeSettings? = nil) {
        self.amounts = amounts
        self.nudges = nudges
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.singleValueContainer().decode([String: [Double]].self)
        amounts = values["amounts"] ?? []
        if let fields = values["nudges"], fields.count == 3,
           fields[0] == 0 || fields[0] == 1,
           let start = Int(exactly: fields[1]), let end = Int(exactly: fields[2]) {
            nudges = WaterNudgeSettings(isEnabled: fields[0] == 1, startHour: start, endHour: end)
        }
    }

    func encode(to encoder: any Encoder) throws {
        // Released clients decode a dictionary of numeric arrays. Keep that shape
        // so they can still read custom amounts after this app saves nudge settings.
        var values = ["amounts": amounts]
        if let nudges {
            values["nudges"] = [nudges.isEnabled ? 1 : 0, Double(nudges.startHour), Double(nudges.endHour)]
        }
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}

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
    var nudgeSettings: WaterNudgeSettings {
        (try? JSONDecoder().decode(WaterPreferencesPayload.self, from: presetsData))?.nudges ?? WaterNudgeSettings()
    }
    var presets: [Double] {
        // New saves use a keyed payload so explicitly choosing 32 oz remains
        // possible after upgrading the original fourth preset to 24 oz.
        if let payload = try? JSONDecoder().decode(WaterPreferencesPayload.self, from: presetsData),
           payload.amounts.count == 4,
           payload.amounts.allSatisfy(WaterUnit.isValidAmount) {
            return payload.amounts
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
