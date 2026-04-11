import SwiftUI
import SwiftData
import Combine

@MainActor
final class HabitDetailViewModel: ObservableObject {
    // MARK: - Inputs
    let habit: Habit
    let prewarmedMonth: MonthHeatmapModel?

    // MARK: - Published UI state
    @Published var monthAnchor: Date
    @Published var monthModel: MonthHeatmapModel
    @Published private(set) var cachedWeeklyPercent: Double
    @Published private(set) var cachedStreaks: (current: Int, best: Int)
    @Published private(set) var cachedRecentCompleted7: Int
    @Published private(set) var cachedRecentCompleted14: Int

    // MARK: - Init
    init(habit: Habit, prewarmedMonth: MonthHeatmapModel? = nil) {
        self.habit = habit
        self.prewarmedMonth = prewarmedMonth

        let today = Calendar.current.startOfDay(for: Date())
        let anchor = prewarmedMonth?.month ?? today
        self.monthAnchor = anchor

        if let prewarmedMonth {
            self.monthModel = prewarmedMonth
        } else {
            self.monthModel = MonthHeatmapModel(habit: habit, month: anchor, logs: habit.logs)
        }

        // Precompute metrics so the view doesn’t rebuild sets on every render.
        let metrics = HabitDetailViewModel.computeMetrics(for: habit.logs ?? [])
        self.cachedWeeklyPercent = metrics.weekly
        self.cachedStreaks = metrics.streaks
        self.cachedRecentCompleted7 = metrics.recentCompleted7
        self.cachedRecentCompleted14 = metrics.recentCompleted14
    }

    // MARK: - Derived
    var habitTint: Color {
        habit.accentColor
    }

    var logs: [HabitLog] {
        habit.logs ?? []
    }

    // MARK: - Intent / Actions
    func goToPreviousMonth() {
        let cal = Calendar.current
        if let prev = cal.date(byAdding: .month, value: -1, to: monthAnchor) {
            monthAnchor = prev
            monthModel = MonthHeatmapModel(habit: habit, month: prev, logs: logs)
        }
    }

    func goToNextMonth() {
        let cal = Calendar.current
        if let next = cal.date(byAdding: .month, value: 1, to: monthAnchor) {
            monthAnchor = next
            monthModel = MonthHeatmapModel(habit: habit, month: next, logs: logs)
        }
    }

    // MARK: - Metrics
    func weeklyPercent() -> Double {
        cachedWeeklyPercent
    }

    func streaks() -> (current: Int, best: Int) {
        cachedStreaks
    }

    /// Recompute the month heatmap and cached metrics from the latest logs.
    func refreshFromStore() {
        let latestLogs = logs
        monthModel = MonthHeatmapModel(habit: habit, month: monthAnchor, logs: latestLogs)
        let metrics = HabitDetailViewModel.computeMetrics(for: latestLogs)
        cachedWeeklyPercent = metrics.weekly
        cachedStreaks = metrics.streaks
        cachedRecentCompleted7 = metrics.recentCompleted7
        cachedRecentCompleted14 = metrics.recentCompleted14
    }

    private static func computeMetrics(for logs: [HabitLog]) -> (
        weekly: Double,
        streaks: (current: Int, best: Int),
        recentCompleted7: Int,
        recentCompleted14: Int
    ) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Normalize completed log dates into a set once so render-facing counters
        // can be derived without repeated per-view filtering.
        let completedDays = Set(
            logs
                .filter { $0.completed && $0.date <= today }
                .map { cal.startOfDay(for: $0.date) }
        )

        let recentCompleted7 = completedDaysCount(
            inLast: 7,
            today: today,
            calendar: cal,
            completedDays: completedDays
        )
        let recentCompleted14 = completedDaysCount(
            inLast: 14,
            today: today,
            calendar: cal,
            completedDays: completedDays
        )
        let weekly = Double(recentCompleted7) / 7.0
        let streaks = StreakEngine.computeStreaks(logs: logs)
        return (weekly, streaks, recentCompleted7, recentCompleted14)
    }

    private static func completedDaysCount(
        inLast days: Int,
        today: Date,
        calendar: Calendar,
        completedDays: Set<Date>
    ) -> Int {
        guard days > 0 else { return 0 }

        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        var count = 0
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if completedDays.contains(calendar.startOfDay(for: day)) {
                count += 1
            }
        }
        return count
    }
}
