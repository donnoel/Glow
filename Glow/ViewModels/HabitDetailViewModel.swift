import Foundation
import SwiftData

@MainActor
final class HabitDetailViewModel: ObservableObject {
    // MARK: - Inputs
    @Published private(set) var habit: Habit

    private let calendar: Calendar
    private let today: Date

    // MARK: - Init
    init(
        habit: Habit,
        calendar: Calendar = .current,
        today: Date = Date()
    ) {
        self.habit = habit
        self.calendar = calendar
        // normalize to start of day so everything agrees on "today"
        self.today = calendar.startOfDay(for: today)
    }

    // MARK: - Streaks

    /// Uses your existing StreakEngine to get current/best streak
    var streaks: (current: Int, best: Int) {
        StreakEngine.computeStreaks(
            logs: habit.logs,
            today: today,
            calendar: calendar
        )
    }

    // MARK: - Recent / Weekly

    /// Returns how many of the last `windowDays` were completed.
    /// You can use this to show "this week" or "last 10 days" in the detail view.
    func completionSummary(last windowDays: Int = 7) -> (done: Int, total: Int, percent: Double) {
        guard windowDays > 0 else { return (0, 0, 0) }

        let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today)!
        let days = (0..<windowDays).compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: offset, to: start).map {
                calendar.startOfDay(for: $0)
            }
        }

        // make a set of completed days from habit logs
        let completedDays: Set<Date> = Set(
            habit.logs
                .filter { $0.completed }
                .map { calendar.startOfDay(for: $0.date) }
        )

        let doneCount = days.filter { completedDays.contains($0) }.count
        let pct = Double(doneCount) / Double(windowDays)

        return (doneCount, windowDays, pct)
    }

    /// Convenience for "this week" style ring
    var weeklyPercent: Double {
        completionSummary(last: 7).percent
    }

    // MARK: - Month data

    struct MonthData {
        let monthStart: Date
        let monthTitle: String
        let inMonthDays: [Date]
        let completedDays: Set<Date>
        let completionPercent: Double
    }

    /// Build all the data the month view needs so the view can stay dumb.
    func monthData(for monthAnchor: Date) -> MonthData {
        // 1. month start
        let comps = calendar.dateComponents([.year, .month], from: monthAnchor)
        let monthStart = calendar.date(from: comps) ?? monthAnchor

        // 2. all days in that month
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1...28
        let inMonthDays: [Date] = range.compactMap { day -> Date? in
            var dc = DateComponents()
            dc.year = comps.year
            dc.month = comps.month
            dc.day = day
            return calendar.date(from: dc).map { calendar.startOfDay(for: $0) }
        }

        // 3. completed days for THIS habit
        let completedDays: Set<Date> = Set(
            habit.logs
                .filter { $0.completed }
                .map { calendar.startOfDay(for: $0.date) }
        )

        // 4. percent for the month
        let hits = inMonthDays.filter { completedDays.contains($0) }.count
        let pct = inMonthDays.isEmpty ? 0 : Double(hits) / Double(inMonthDays.count)

        // 5. title, e.g. "November 2025"
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "LLLL yyyy"
        let title = f.string(from: monthStart)

        return MonthData(
            monthStart: monthStart,
            monthTitle: title,
            inMonthDays: inMonthDays,
            completedDays: completedDays,
            completionPercent: pct
        )
    }
}
