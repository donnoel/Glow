import Foundation

enum StreakEngine {
    /// Returns (currentStreak, bestStreak) counting only days with a completed log.
    /// Assumes a daily schedule for M3 (we can add custom schedules in the next milestone).
    static func computeStreaks(
        logs: [HabitLog],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> (current: Int, best: Int) {
        // Normalize and keep only completed days
        let completedDays = Set(
            logs.filter { $0.completed }.map { calendar.startOfDay(for: $0.date) }
        )

        // Current streak: walk backward from today while each day is completed
        var current = 0
        var day = calendar.startOfDay(for: today)
        while completedDays.contains(day) {
            current += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = calendar.startOfDay(for: prev)
        }

        // Best streak: scan last 1 year rolling window
        var best = current
        var rolling = 0
        var cursor = calendar.startOfDay(for: today)
        for _ in 0..<365 {
            if completedDays.contains(cursor) {
                rolling += 1
                best = max(best, rolling)
            } else {
                rolling = 0
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: prev)
        }

        return (current, best)
    }
}
