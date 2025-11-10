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

    // MARK: - Init
    init(habit: Habit, prewarmedMonth: MonthHeatmapModel? = nil) {
        self.habit = habit
        self.prewarmedMonth = prewarmedMonth
        // prefer the prewarmed month if we got one, otherwise today
        self.monthAnchor = prewarmedMonth?.month ?? .now
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
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) {
            monthAnchor = prev
        }
    }

    func goToNextMonth() {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) {
            monthAnchor = next
        }
    }

    // MARK: - Metrics
    func weeklyPercent() -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // last 7 days including today
        guard let start = cal.date(byAdding: .day, value: -6, to: today) else {
            return 0.0
        }

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

        return Double(hits) / 7.0
    }

    func streaks() -> (current: Int, best: Int) {
        StreakEngine.computeStreaks(logs: logs)
    }
}
