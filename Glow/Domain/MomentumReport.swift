import Foundation

enum MomentumReportPeriod: String, CaseIterable, Identifiable {
    case weekly, monthly, quarterly, annual, lifetime

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var explanation: String {
        switch self {
        case .weekly: "The last seven days, including today."
        case .monthly: "This calendar month, through today."
        case .quarterly: "This calendar quarter, through today."
        case .annual: "This calendar year, through today."
        case .lifetime: "From your earliest included habit or water log, through today."
        }
    }

    func start(now: Date, earliest: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .weekly:
            return calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .monthly:
            return calendar.dateInterval(of: .month, for: today)?.start ?? today
        case .quarterly:
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            let months = ((calendar.component(.month, from: today) - 1) / 3) * 3
            return calendar.date(byAdding: .month, value: months, to: yearStart) ?? today
        case .annual:
            return calendar.dateInterval(of: .year, for: today)?.start ?? today
        case .lifetime:
            return min(today, calendar.startOfDay(for: earliest))
        }
    }
}

enum MomentumReportScope: String, CaseIterable, Identifiable {
    case all, active

    var id: String { rawValue }
    var title: String { self == .all ? "All habits" : "Active only" }
}

struct MomentumReport {
    struct HabitSummary: Identifiable {
        let id: String
        let title: String
        let isArchived: Bool
        let scheduled: Int
        let completed: Int
        let bonus: Int

        var detail: String {
            if isArchived { return "\(completed + bonus) recorded check-ins · Archived" }
            let scheduledText = scheduled > 0
                ? "\(completed) of \(scheduled) scheduled check-ins (\(MomentumReport.percent(completed, scheduled))%)"
                : "No scheduled check-ins"
            return bonus > 0 ? "\(scheduledText); \(bonus) bonus check-ins" : scheduledText
        }
    }

    let period: MomentumReportPeriod
    let scope: MomentumReportScope
    let start: Date
    let end: Date
    let dayCount: Int
    let habits: [HabitSummary]
    let activeDays: Int
    let waterLoggedDays: Int
    let waterGoalDays: Int
    let waterKnownGoalDays: Int
    let waterTotal: Double
    let waterUnit: WaterUnit
    let dateRange: String

    var title: String { "\(period.title) momentum" }
    var scheduled: Int { habits.filter { !$0.isArchived }.reduce(0) { $0 + $1.scheduled } }
    var completed: Int { habits.filter { !$0.isArchived }.reduce(0) { $0 + $1.completed } }
    var bonus: Int { habits.filter { !$0.isArchived }.reduce(0) { $0 + $1.bonus } }
    var totalCheckIns: Int { habits.reduce(0) { $0 + $1.completed + $1.bonus } }
    var archivedCheckIns: Int { habits.filter(\.isArchived).reduce(0) { $0 + $1.completed + $1.bonus } }
    var completionPercent: Int? { scheduled > 0 ? Self.percent(completed, scheduled) : nil }

    var momentumText: String {
        guard !habits.isEmpty else { return "No \(scope == .active ? "active " : "")habits to report in this period." }
        var lines = ["\(totalCheckIns) total check-ins across \(activeDays) of \(dayCount) days"]
        if habits.contains(where: { !$0.isArchived }) {
            lines.append(completionPercent.map { "\($0)% of scheduled check-ins completed for active habits." }
                         ?? "No scheduled check-ins for active habits in this period.")
            lines.append("Active habits: \(completed) of \(scheduled) scheduled check-ins · \(bonus) bonus check-ins")
        }
        if habits.contains(where: \.isArchived) {
            lines.append("\(archivedCheckIns) recorded check-ins from archived habits. Archived habits are excluded from the scheduled rate.")
        }
        return lines.joined(separator: "\n")
    }

    var waterText: String {
        guard waterLoggedDays > 0 else { return "No water logged in this period. Unlogged days are not treated as zero intake." }
        var lines = [
            "Water logged on \(waterLoggedDays) of \(dayCount) days",
            "\(waterUnit.label(waterTotal)) total · \(waterUnit.label(waterTotal / Double(waterLoggedDays))) average on logged days",
            "Saved daily goal reached on \(waterGoalDays) of \(waterKnownGoalDays) logged days with a saved goal"
        ]
        if waterKnownGoalDays < waterLoggedDays {
            lines.append("\(waterLoggedDays - waterKnownGoalDays) logged days have no saved goal.")
        }
        return lines.joined(separator: "\n")
    }

    var notes: String {
        let included = scope == .all ? "Includes all saved habits, including archived habits." : "Includes currently active habits only."
        return "\(included) Each habit counts once per day. Scheduled rates cover currently active habits using their current schedules from creation. Past schedule changes and pause/archive dates are not stored; archived habits contribute recorded check-ins only. Deleted habits cannot be recovered. Today is still in progress. Water stays separate from habit momentum and uses saved daily goals; unlogged days are not zero intake. Reflects data available on this device."
    }

    /// The preview and every sharing destination use these same values.
    var shareText: String {
        var sections = ["Glow · \(title)\n\(dateRange)\n\(scope.title)", "MOMENTUM\n\(momentumText)"]
        if !habits.isEmpty {
            sections.append("BY HABIT\n" + habits.map { "\($0.title)\n\($0.detail)" }.joined(separator: "\n\n"))
        }
        sections.append("WATER RHYTHM\n\(waterText)")
        sections.append("ABOUT THIS REPORT\n\(notes)")
        return sections.joined(separator: "\n\n")
    }

    private static func percent(_ completed: Int, _ scheduled: Int) -> Int {
        Int((Double(completed) / Double(scheduled) * 100).rounded())
    }
}

enum MomentumReportBuilder {
    static func make(
        period: MomentumReportPeriod,
        scope: MomentumReportScope = .all,
        habits: [Habit],
        entries: [WaterEntryValue],
        goals: [WaterGoalValue],
        unit: WaterUnit,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MomentumReport {
        let today = calendar.startOfDay(for: now)
        let included = habits.filter {
            (scope == .all || !$0.isArchived) && calendar.startOfDay(for: $0.createdAt) <= today
        }
        let validEntries = entries.filter { $0.timestamp <= now && WaterUnit.isValidAmount($0.milliliters) }
        let waterStart = validEntries.compactMap { civilDate($0.dayKey, calendar: calendar) }.min()
        let earliest = (included.map(\.createdAt) + [waterStart].compactMap { $0 }).min() ?? today
        let start = period.start(now: now, earliest: earliest, calendar: calendar)
        let dayCount = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        let dates = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        var activeDays: Set<Date> = []
        let summaries = included.map { habit in
            let created = calendar.startOfDay(for: habit.createdAt)
            let completedDays = Set((habit.logs ?? []).filter(\.completed).map { calendar.startOfDay(for: $0.date) })
            let schedule = habit.schedule
            var scheduled = 0
            var completed = 0
            var bonus = 0
            for date in dates where date >= created {
                let isCompleted = completedDays.contains(date)
                if schedule.isScheduled(on: date, calendar: calendar) {
                    scheduled += 1
                    if isCompleted { completed += 1 }
                } else if isCompleted {
                    bonus += 1
                }
                if isCompleted { activeDays.insert(date) }
            }
            return MomentumReport.HabitSummary(id: habit.id, title: habit.title, isArchived: habit.isArchived, scheduled: scheduled,
                                              completed: completed, bonus: bonus)
        }
        let waterDays = WaterAnalytics.summaries(entries: validEntries, goals: goals,
                                                days: dayCount, now: now, calendar: calendar).filter(\.isLogged)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return MomentumReport(
            period: period, scope: scope, start: start, end: today, dayCount: dayCount,
            habits: summaries, activeDays: activeDays.count,
            waterLoggedDays: waterDays.count, waterGoalDays: waterDays.filter(\.reachedGoal).count,
            waterKnownGoalDays: waterDays.filter { $0.goalMilliliters != nil }.count,
            waterTotal: waterDays.reduce(0) { $0 + $1.milliliters }, waterUnit: unit,
            dateRange: "\(formatter.string(from: start)) – \(formatter.string(from: today))"
        )
    }

    private static func civilDate(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var civilCalendar = Calendar(identifier: .gregorian)
        civilCalendar.timeZone = calendar.timeZone
        guard let date = civilCalendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              WaterAnalytics.dayKey(date, calendar: calendar) == key else { return nil }
        return date
    }
}
