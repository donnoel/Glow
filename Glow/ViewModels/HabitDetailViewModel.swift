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
    }

    private static func computeMetrics(for logs: [HabitLog]) -> (weekly: Double, streaks: (current: Int, best: Int)) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // last 7 days including today
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today

        // normalize completed log dates into a set
        let completed = Set(
            logs
                .filter { $0.completed && $0.date >= start }
                .map { cal.startOfDay(for: $0.date) }
        )

        var hits = 0
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let d = cal.startOfDay(for: day)
            if completed.contains(d) {
                hits += 1
            }
        }

        let weekly = Double(hits) / 7.0
        let streaks = StreakEngine.computeStreaks(logs: logs)
        return (weekly, streaks)
    }
}
