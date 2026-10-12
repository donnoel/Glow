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
    private static let opportunityFractions = [0.30, 0.55, 0.80]
    private static let minimumSpacing: TimeInterval = 3 * 60 * 60
    private static let drinkPause: TimeInterval = 90 * 60

    static func plan(input: WaterNudgeInput, settings: WaterNudgeSettings, now: Date,
                     calendar: Calendar = .current) -> [WaterNudgePlanItem] {
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
        let lastOpportunity = end.addingTimeInterval(-60 * 60)
        // Wait until the current total falls ten percentage points behind a steady daytime pace.
        let crossingFraction = input.totalMilliliters / input.goalMilliliters + 0.10
        let crossing = start.addingTimeInterval(duration * crossingFraction)
        let recentDrink = input.lastDrinkAt.flatMap { date -> Date? in
            guard date <= now, GlowWatchDay(date: date, calendar: calendar) == input.day else { return nil }
            return date.addingTimeInterval(drinkPause)
        }
        var items: [WaterNudgePlanItem] = []

        for (index, fraction) in opportunityFractions.enumerated() {
            let earliest = start.addingTimeInterval(duration * fraction)
            let slotEnd = index + 1 < opportunityFractions.count
                ? start.addingTimeInterval(duration * opportunityFractions[index + 1]) : end
            var fireDate = max(earliest, crossing)
            if let recentDrink { fireDate = max(fireDate, recentDrink) }
            if let previous = items.last { fireDate = max(fireDate, previous.fireDate.addingTimeInterval(minimumSpacing)) }
            // Do not catch up a missed alert or squeeze delayed alerts together.
            guard fireDate > now, fireDate < slotEnd, fireDate <= lastOpportunity else { continue }
            let message = message(index: index, input: input, fireDate: fireDate, end: end)
            items.append(WaterNudgePlanItem(
                identifier: "\(identifierPrefix)\(input.day.waterDayKey).\(index)",
                fireDate: fireDate, title: message.title, body: message.body
            ))
        }
        return items
    }

    private static func message(index: Int, input: WaterNudgeInput, fireDate: Date,
                                end: Date) -> (title: String, body: String) {
        let remaining = input.unit.label(input.goalMilliliters - input.totalMilliliters)
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
