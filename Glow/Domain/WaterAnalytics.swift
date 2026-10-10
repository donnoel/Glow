import Foundation

nonisolated enum WaterGoalProfile: String, CaseIterable, Identifiable {
    case male, female, custom
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var suggestedMilliliters: Double? {
        switch self {
        case .male: WaterUnit.ounces.milliliters(from: 100)
        case .female: WaterUnit.ounces.milliliters(from: 75)
        case .custom: nil
        }
    }
}

struct WaterEntryValue: Equatable {
    let id: String
    let dayKey: String
    let timestamp: Date
    let milliliters: Double

    init(_ entry: WaterEntry) {
        id = entry.id
        dayKey = entry.dayKey
        timestamp = entry.timestamp
        milliliters = entry.milliliters
    }
}

struct WaterGoalValue: Equatable {
    let id: String
    let dayKey: String
    let createdAt: Date
    let milliliters: Double

    init(_ goal: WaterDayGoal) {
        id = goal.id
        dayKey = goal.dayKey
        createdAt = goal.createdAt
        milliliters = goal.milliliters
    }
}

struct WaterDaySummary: Identifiable {
    let date: Date
    let id: String
    let milliliters: Double
    let goalMilliliters: Double?
    let entryCount: Int
    var isLogged: Bool { entryCount > 0 }
    var reachedGoal: Bool {
        guard isLogged, let goalMilliliters else { return false }
        return milliliters + 0.001 >= goalMilliliters
    }
}

enum WaterAnalytics {
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        var civilCalendar = Calendar(identifier: .gregorian)
        civilCalendar.timeZone = calendar.timeZone
        let components = civilCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func summaries(entries: [WaterEntryValue], goals: [WaterGoalValue],
                          days: Int, now: Date = .now, calendar: Calendar = .current) -> [WaterDaySummary] {
        let entriesByDay = Dictionary(grouping: entries, by: \.dayKey)
        // Offline devices can each create a day's snapshot. The earliest wins,
        // with an ID tie-breaker so every device resolves duplicates consistently.
        let goalsByDay = Dictionary(grouping: goals, by: \.dayKey)
            .mapValues { values in
                values.min { lhs, rhs in
                    lhs.createdAt == rhs.createdAt ? lhs.id < rhs.id : lhs.createdAt < rhs.createdAt
                }?.milliliters
            }
        let today = calendar.startOfDay(for: now)
        guard days > 0 else { return [] }
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = dayKey(date, calendar: calendar)
            let drinks = (entriesByDay[key] ?? []).filter { WaterUnit.isValidAmount($0.milliliters) }
            return WaterDaySummary(date: date, id: key,
                                   milliliters: drinks.reduce(0) { $0 + $1.milliliters },
                                   goalMilliliters: goalsByDay[key] ?? nil, entryCount: drinks.count)
        }
    }
}
