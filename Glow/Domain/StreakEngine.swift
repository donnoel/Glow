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

        // Current streak: walk backward from today until the first gap.
        var current = 0
        var day = calendar.startOfDay(for: today)
        while completedDays.contains(day) {
            current += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = calendar.startOfDay(for: prev)
        }

        // Best streak: scan the entire history (not capped to 365 days).
        var best = 0
        var rolling = 0
        var previousDay: Date?
        for date in completedDays.sorted() {
            if let prev = previousDay,
               calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: prev) ?? prev) {
                rolling += 1
            } else {
                rolling = 1
            }
            best = max(best, rolling)
            previousDay = date
        }
        best = max(best, current)

        return (current, best)
    }
}
