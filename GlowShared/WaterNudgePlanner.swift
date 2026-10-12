import Foundation

nonisolated struct WaterNudgeSettings: Codable, Equatable, Sendable {
    var isEnabled = false
    var startHour = 8
    var endHour = 21

    var isValid: Bool {
        (0...23).contains(startHour) && (0...23).contains(endHour) && endHour - startHour >= 6
    }
}

nonisolated struct WaterNudgeInput: Equatable, Sendable {
    let day: GlowWatchDay
    let totalMilliliters: Double
    let goalMilliliters: Double
    let lastDrinkAt: Date?
    let unit: WaterUnit
}

nonisolated struct WaterNudgePlanItem: Codable, Equatable, Sendable {
    let identifier: String
    let fireDate: Date
    let title: String
    let body: String
}

/// A finite plan for today's logged progress, recalculated whenever that progress changes.
nonisolated enum WaterNudgePlanner {
    static let identifierPrefix = "water.nudge."
    private static let minimumSpacing: TimeInterval = 3 * 60 * 60
    private static let firstNudgeDelay: TimeInterval = 5 * 60

    static func plan(input: WaterNudgeInput, settings: WaterNudgeSettings, now: Date,
                     calendar: Calendar = .current,
                     existingFireDates: [String: Date] = [:],
                     notBefore: Date? = nil,
                     spentIdentifiers: Set<String> = []) -> [WaterNudgePlanItem] {
        guard settings.isEnabled, settings.isValid,
              input.day == GlowWatchDay(date: now, calendar: calendar),
              input.totalMilliliters.isFinite, input.totalMilliliters >= 0,
              WaterUnit.isValidAmount(input.goalMilliliters), input.totalMilliliters < input.goalMilliliters,
              let day = input.day.date(calendar: calendar),
              let start = calendar.date(bySettingHour: settings.startHour, minute: 0, second: 0, of: day),
              let end = calendar.date(bySettingHour: settings.endHour, minute: 0, second: 0, of: day),
              GlowWatchDay(date: start, calendar: calendar) == input.day,
              GlowWatchDay(date: end, calendar: calendar) == input.day,
              end > start else { return [] }

        let duration = end.timeIntervalSince(start)
        // Wait until the current total falls ten percentage points behind a steady daytime pace.
        let crossingFraction = input.totalMilliliters / input.goalMilliliters + 0.10
        let crossing = start.addingTimeInterval(duration * crossingFraction)
        let expectedProgress = min(1, max(0, now.timeIntervalSince(start) / duration))
        // A larger shortfall makes a water break useful sooner, while still giving a drink quiet time.
        let drinkPause: TimeInterval = expectedProgress - input.totalMilliliters / input.goalMilliliters >= 0.25
            ? 45 * 60 : 90 * 60
        let recentDrink = input.lastDrinkAt.flatMap { date -> Date? in
            guard date <= now, GlowWatchDay(date: date, calendar: calendar) == input.day else { return nil }
            return date.addingTimeInterval(drinkPause)
        }
        var items: [WaterNudgePlanItem] = []

        for index in 0..<3 {
            let identifier = "\(identifierPrefix)\(input.day.waterDayKey).\(index)"
            guard !spentIdentifiers.contains(identifier) else { continue }
            var fireDate = crossing
            if let recentDrink { fireDate = max(fireDate, recentDrink) }
            if let notBefore { fireDate = max(fireDate, notBefore) }
            if let previous = items.last { fireDate = max(fireDate, previous.fireDate.addingTimeInterval(minimumSpacing)) }
            if fireDate <= now {
                // A late start still gets one useful opportunity. Refreshes must not keep moving it away.
                if let existing = existingFireDates[identifier], existing > now {
                    fireDate = existing
                } else {
                    fireDate = now.addingTimeInterval(firstNudgeDelay)
                }
            }
            guard fireDate > now, fireDate < end else { continue }
            let message = message(index: index, input: input, fireDate: fireDate, end: end)
            items.append(WaterNudgePlanItem(
                identifier: identifier,
                fireDate: fireDate, title: message.title, body: message.body
            ))
        }
        return items
    }

    private static func message(index: Int, input: WaterNudgeInput, fireDate: Date,
                                end: Date) -> (title: String, body: String) {
        let remaining = input.unit.label(input.goalMilliliters - input.totalMilliliters)
        if end.timeIntervalSince(fireDate) < 3_600 {
            return ("A little water before winding down?",
                    "If you haven’t logged more, \(remaining) remains toward today’s goal. Enjoy a few comfortable sips.")
        }
        let hours = (end.timeIntervalSince(fireDate) / 3_600).formatted(.number.precision(.fractionLength(0...1)))
        let progress = "If you haven’t logged more, \(remaining) remains toward your goal over about \(hours) hours."
        switch index {
        case 0:
            return ("A little water break?", "\(progress) A small drink can help.")
        case 1:
            return ("Time for water", "\(progress) Keep it comfortable, a little at a time.")
        default:
            return ("A gentle water check-in", "\(progress) Enjoy a few relaxed sips.")
        }
    }
}
