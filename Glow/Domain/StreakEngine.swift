import Foundation

enum StreakEngine {
    static func computeStreaks(
        logs: [HabitLog],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> (current: Int, best: Int) {
        let completedDays = Set(
            logs.filter { $0.completed }.map { calendar.startOfDay(for: $0.date) }
        )

        var current = 0
        var day = calendar.startOfDay(for: today)
        while completedDays.contains(day) {
            current += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = calendar.startOfDay(for: prev)
        }

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
