import Combine
import Foundation

@MainActor
final class InsightsViewModel: ObservableObject {
    enum DayState: Equatable {
        case completed
        case open
        case bonus
        case notScheduled
    }

    struct Day: Identifiable, Equatable {
        let date: Date
        let isToday: Bool

        var id: Date { date }
    }

    struct HabitRhythm: Identifiable {
        let habit: Habit
        let dayStates: [DayState]
        let completedScheduled: Int
        let scheduled: Int
        let previousCompletedScheduled: Int
        let previousScheduled: Int
        let bonusCompletions: Int
        let openPastDays: Int

        var id: String { habit.id }

        var completionPercent: Int? {
            Self.percent(completed: completedScheduled, scheduled: scheduled)
        }

        var previousCompletionPercent: Int? {
            Self.percent(completed: previousCompletedScheduled, scheduled: previousScheduled)
        }

        var percentagePointChange: Int? {
            guard let completionPercent, let previousCompletionPercent else { return nil }
            return completionPercent - previousCompletionPercent
        }

        var accessibilitySummary: String {
            var parts = ["\(habit.title). \(completedScheduled) of \(scheduled) scheduled check-ins completed."]
            if openPastDays > 0 {
                parts.append("\(openPastDays) past scheduled day\(openPastDays == 1 ? "" : "s") without a check-in.")
            }
            if bonusCompletions > 0 {
                parts.append("\(bonusCompletions) bonus check-in\(bonusCompletions == 1 ? "" : "s") on unscheduled days.")
            }
            return parts.joined(separator: " ")
        }

        private static func percent(completed: Int, scheduled: Int) -> Int? {
            guard scheduled > 0 else { return nil }
            return Int((Double(completed) / Double(scheduled) * 100).rounded())
        }
    }

    struct Highlight: Identifiable {
        enum Kind {
            case milestone
            case improving
            case steady
            case worthALook

            var symbol: String {
                switch self {
                case .milestone: return "sparkles"
                case .improving: return "arrow.up.forward"
                case .steady: return "heart.fill"
                case .worthALook: return "magnifyingglass"
                }
            }
        }

        let id: String
        let kind: Kind
        let title: String
        let detail: String
        let habit: Habit?
    }

    @Published private(set) var days: [Day] = []
    @Published private(set) var habitRhythms: [HabitRhythm] = []
    @Published private(set) var highlights: [Highlight] = []
    @Published private(set) var completedScheduled = 0
    @Published private(set) var scheduled = 0
    @Published private(set) var previousCompletedScheduled = 0
    @Published private(set) var previousScheduled = 0
    @Published private(set) var activeDays = 0
    @Published private(set) var lifetimeCompletions = 0
    @Published private(set) var lifetimeActiveDays = 0
    @Published private(set) var globalStreak: (current: Int, best: Int) = (0, 0)

    private(set) var now: Date
    private let calendar: Calendar

    init(
        habits: [Habit] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.now = now
        self.calendar = calendar
        recalc(habits: habits, now: now)
    }

    var completionPercent: Int? {
        Self.percent(completed: completedScheduled, scheduled: scheduled)
    }

    var previousCompletionPercent: Int? {
        Self.percent(completed: previousCompletedScheduled, scheduled: previousScheduled)
    }

    var percentagePointChange: Int? {
        guard let completionPercent, let previousCompletionPercent else { return nil }
        return completionPercent - previousCompletionPercent
    }

    var dateRangeText: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "Last 7 days" }
        let firstText = first.formatted(.dateTime.month(.abbreviated).day())
        let lastText = last.formatted(.dateTime.month(.abbreviated).day())
        return "\(firstText)–\(lastText)"
    }

    var storyTitle: String {
        guard !habitRhythms.isEmpty else { return "Insights start with your first habit" }
        guard let completionPercent else { return "A flexible seven days" }

        if completionPercent == 100 {
            return "A complete seven days"
        }

        guard let percentagePointChange else { return "Your first seven-day baseline" }
        switch percentagePointChange {
        case 15...:
            return "A stronger seven days"
        case 5..<15:
            return "Momentum is growing"
        case ...(-15):
            return "A quieter seven days"
        case -14 ..< -4:
            return "Your rhythm eased a little"
        default:
            return "A steady seven days"
        }
    }

    var storySummary: String {
        guard !habitRhythms.isEmpty else {
            return "Add a habit and check in to begin seeing your rhythm."
        }

        guard scheduled > 0 else {
            return activeDays > 0
                ? "You checked in on \(activeDays) day\(activeDays == 1 ? "" : "s"), with no scheduled check-ins in this window."
                : "There were no scheduled check-ins in this window."
        }

        return "You completed \(completedScheduled) of \(scheduled) scheduled check-ins across \(activeDays) active day\(activeDays == 1 ? "" : "s")."
    }

    var comparisonText: String {
        guard scheduled > 0 else { return "Scheduled opportunities will appear here as your week unfolds." }
        guard previousScheduled > 0, let percentagePointChange else {
            return "This creates a baseline for your next seven-day comparison."
        }

        switch percentagePointChange {
        case 1...:
            return "Up \(percentagePointChange) percentage point\(percentagePointChange == 1 ? "" : "s") from the previous seven days."
        case ..<0:
            let amount = abs(percentagePointChange)
            return "Down \(amount) percentage point\(amount == 1 ? "" : "s") from the previous seven days."
        default:
            return "Matching the previous seven days."
        }
    }

    func recalc(habits: [Habit], now: Date) {
        self.now = now
        let today = calendar.startOfDay(for: now)
        let currentDates = dates(endingAt: today, count: 7)
        let previousEnd = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let previousDates = dates(endingAt: previousEnd, count: 7)
        let activeHabits = habits
            .filter { !$0.isArchived }
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortOrder < $1.sortOrder
            }

        let rhythms = activeHabits.map { habit in
            makeRhythm(
                for: habit,
                currentDates: currentDates,
                previousDates: previousDates,
                today: today
            )
        }

        let completedDays = Set(
            activeHabits
                .flatMap { $0.logs ?? [] }
                .filter(\.completed)
                .map { calendar.startOfDay(for: $0.date) }
        )
        let allCompletedLogs = activeHabits
            .flatMap { $0.logs ?? [] }
            .filter(\.completed)

        days = currentDates.map { Day(date: $0, isToday: calendar.isDate($0, inSameDayAs: today)) }
        habitRhythms = rhythms
        completedScheduled = rhythms.reduce(0) { $0 + $1.completedScheduled }
        scheduled = rhythms.reduce(0) { $0 + $1.scheduled }
        previousCompletedScheduled = rhythms.reduce(0) { $0 + $1.previousCompletedScheduled }
        previousScheduled = rhythms.reduce(0) { $0 + $1.previousScheduled }
        activeDays = currentDates.filter(completedDays.contains).count
        lifetimeCompletions = allCompletedLogs.count
        lifetimeActiveDays = completedDays.count
        globalStreak = StreakEngine.computeStreaks(
            logs: allCompletedLogs,
            today: today,
            calendar: calendar
        )
        highlights = makeHighlights(
            rhythms: rhythms,
            currentDates: currentDates,
            completedLogs: allCompletedLogs
        )
    }

    private func makeRhythm(
        for habit: Habit,
        currentDates: [Date],
        previousDates: [Date],
        today: Date
    ) -> HabitRhythm {
        let createdDay = calendar.startOfDay(for: habit.createdAt)
        let completedDays = Set(
            (habit.logs ?? [])
                .filter(\.completed)
                .map { calendar.startOfDay(for: $0.date) }
        )

        let current = metrics(
            habit: habit,
            dates: currentDates,
            createdDay: createdDay,
            completedDays: completedDays,
            today: today
        )
        let previous = metrics(
            habit: habit,
            dates: previousDates,
            createdDay: createdDay,
            completedDays: completedDays,
            today: today
        )

        return HabitRhythm(
            habit: habit,
            dayStates: current.states,
            completedScheduled: current.completedScheduled,
            scheduled: current.scheduled,
            previousCompletedScheduled: previous.completedScheduled,
            previousScheduled: previous.scheduled,
            bonusCompletions: current.bonusCompletions,
            openPastDays: current.openPastDays
        )
    }

    private func metrics(
        habit: Habit,
        dates: [Date],
        createdDay: Date,
        completedDays: Set<Date>,
        today: Date
    ) -> (
        states: [DayState],
        completedScheduled: Int,
        scheduled: Int,
        bonusCompletions: Int,
        openPastDays: Int
    ) {
        var completedScheduled = 0
        var scheduled = 0
        var bonusCompletions = 0
        var openPastDays = 0

        let states = dates.map { date -> DayState in
            guard date >= createdDay else { return .notScheduled }

            let isScheduled = habit.schedule.isScheduled(on: date, calendar: calendar)
            let isCompleted = completedDays.contains(date)

            if isScheduled {
                scheduled += 1
                if isCompleted {
                    completedScheduled += 1
                    return .completed
                }
                if date < today {
                    openPastDays += 1
                }
                return .open
            }

            if isCompleted {
                bonusCompletions += 1
                return .bonus
            }
            return .notScheduled
        }

        return (states, completedScheduled, scheduled, bonusCompletions, openPastDays)
    }

    private func makeHighlights(
        rhythms: [HabitRhythm],
        currentDates: [Date],
        completedLogs: [HabitLog]
    ) -> [Highlight] {
        var result: [Highlight] = []
        var usedHabitIDs: Set<String> = []

        let beforeWindowCount: Int
        if let start = currentDates.first {
            beforeWindowCount = completedLogs.filter { $0.date < start }.count
        } else {
            beforeWindowCount = completedLogs.count
        }
        let reachedMilestone = (lifetimeCompletions / 50) * 50
        if reachedMilestone >= 50, beforeWindowCount < reachedMilestone {
            result.append(
                Highlight(
                    id: "milestone-\(reachedMilestone)",
                    kind: .milestone,
                    title: "\(reachedMilestone) check-ins",
                    detail: "You crossed a new lifetime milestone in the last seven days.",
                    habit: nil
                )
            )
        }

        if let improving = rhythms
            .filter({ ($0.percentagePointChange ?? 0) >= 15 && $0.completedScheduled > 0 })
            .max(by: { ($0.percentagePointChange ?? 0) < ($1.percentagePointChange ?? 0) }) {
            let change = improving.percentagePointChange ?? 0
            result.append(
                Highlight(
                    id: "improving-\(improving.id)",
                    kind: .improving,
                    title: "\(improving.habit.title) picked up",
                    detail: "Up \(change) points from the previous seven days, with \(improving.completedScheduled) of \(improving.scheduled) scheduled check-ins.",
                    habit: improving.habit
                )
            )
            usedHabitIDs.insert(improving.id)
        }

        if result.count < 2,
           let anchor = rhythms
            .filter({ $0.completedScheduled > 0 && !usedHabitIDs.contains($0.id) })
            .max(by: { lhs, rhs in
                let lhsPercent = lhs.completionPercent ?? 0
                let rhsPercent = rhs.completionPercent ?? 0
                if lhsPercent == rhsPercent {
                    return lhs.completedScheduled < rhs.completedScheduled
                }
                return lhsPercent < rhsPercent
            }) {
            result.append(
                Highlight(
                    id: "steady-\(anchor.id)",
                    kind: .steady,
                    title: "\(anchor.habit.title) carried your rhythm",
                    detail: "\(anchor.completedScheduled) of \(anchor.scheduled) scheduled check-ins completed.",
                    habit: anchor.habit
                )
            )
            usedHabitIDs.insert(anchor.id)
        }

        if result.count < 2,
           let worthALook = rhythms
            .filter({ $0.openPastDays > 0 && !usedHabitIDs.contains($0.id) })
            .max(by: { lhs, rhs in
                if lhs.openPastDays == rhs.openPastDays {
                    return (lhs.completionPercent ?? 100) > (rhs.completionPercent ?? 100)
                }
                return lhs.openPastDays < rhs.openPastDays
            }) {
            let changeDetail: String
            if let change = worthALook.percentagePointChange, change <= -15 {
                changeDetail = "Down \(abs(change)) points from the previous seven days."
            } else {
                changeDetail = "\(worthALook.openPastDays) past scheduled day\(worthALook.openPastDays == 1 ? "" : "s") without a check-in."
            }
            result.append(
                Highlight(
                    id: "look-\(worthALook.id)",
                    kind: .worthALook,
                    title: "\(worthALook.habit.title) is worth a look",
                    detail: changeDetail,
                    habit: worthALook.habit
                )
            )
        }

        return Array(result.prefix(2))
    }

    private func dates(endingAt end: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - (count - 1), to: end)
                .map { calendar.startOfDay(for: $0) }
        }
    }

    private static func percent(completed: Int, scheduled: Int) -> Int? {
        guard scheduled > 0 else { return nil }
        return Int((Double(completed) / Double(scheduled) * 100).rounded())
    }
}
