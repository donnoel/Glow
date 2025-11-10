import Foundation
import SwiftData
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Source of truth
    @Published private(set) var todayStartOfDay: Date
    @Published private(set) var habits: [Habit] = []

    // MARK: - Init
    init(today: Date = Calendar.current.startOfDay(for: Date())) {
        self.todayStartOfDay = today
    }

    // MARK: - Inputs
    func updateHabits(_ habits: [Habit]) {
        self.habits = habits
        // when habits change, push real numbers to the widget
        pushProgressToWidget()
    }

    func advanceToToday(_ date: Date) {
        self.todayStartOfDay = Calendar.current.startOfDay(for: date)
        // when the day rolls over, push fresh numbers
        pushProgressToWidget()
    }

    // MARK: - Derived Collections

    var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    var archivedHabits: [Habit] {
        habits.filter { $0.isArchived }
    }

    /// All habits scheduled today
    var scheduledTodayHabits: [Habit] {
        activeHabits
            .filter { $0.schedule.isScheduled(on: todayStartOfDay) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Completed today (from scheduled)
    var completedToday: [Habit] {
        let cal = Calendar.current
        return scheduledTodayHabits.filter { habit in
            (habit.logs ?? []).contains { log in
                cal.startOfDay(for: log.date) == todayStartOfDay && log.completed
            }
        }
    }

    /// Due today but not done
    var dueButNotDoneToday: [Habit] {
        let cal = Calendar.current
        return scheduledTodayHabits.filter { habit in
            !(habit.logs ?? []).contains { log in
                cal.startOfDay(for: log.date) == todayStartOfDay && log.completed
            }
        }
    }

    /// Not scheduled today
    var notDueToday: [Habit] {
        activeHabits
            .filter { !$0.schedule.isScheduled(on: todayStartOfDay) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Completed today even though they were NOT scheduled today (bonus)
    var bonusCompletedToday: [Habit] {
        let cal = Calendar.current
        return notDueToday.filter { habit in
            (habit.logs ?? []).contains { log in
                cal.startOfDay(for: log.date) == todayStartOfDay && log.completed
            }
        }
    }

    /// Hero numbers
    var todayCompletion: (done: Int, total: Int, percent: Double) {
        let totalScheduled = scheduledTodayHabits.count
        let doneScheduled = completedToday.count
        let bonus = bonusCompletedToday.count

        let percentValue: Double
        if totalScheduled == 0 {
            // no scheduled practices today
            percentValue = bonus == 0 ? 0.0 : Double(bonus)
        } else {
            percentValue = Double(doneScheduled + bonus) / Double(totalScheduled)
        }

        // 👇 no saving here anymore
        return (doneScheduled, totalScheduled, percentValue)
    }

    /// True when the user has completed all practices that were actually scheduled for today.
    var isTodayComplete: Bool {
        todayCompletion.total > 0 && todayCompletion.done >= todayCompletion.total
    }

    // MARK: - "You" summaries (moved from HomeView)

    /// All logs, flattened from all habits.
    private var allLogs: [HabitLog] {
        habits.compactMap { $0.logs }.flatMap { $0 }
    }

    /// Current streak and best streak *across all habits*.
    /// We treat a "day counts" if you completed ANY habit that day.
    var globalStreak: (current: Int, best: Int) {
        let cal = Calendar.current

        let groupedByDay = Dictionary(grouping: allLogs.filter { $0.completed }) {
            cal.startOfDay(for: $0.date)
        }

        let synthetic: [HabitLog] = groupedByDay.keys.map { day in
            HabitLog(date: day, completed: true, habit: Habit.placeholder)
        }

        return StreakEngine.computeStreaks(logs: synthetic)
    }

    /// Which habit is "most consistent" in the last 14 days?
    var mostConsistentHabit: (title: String, hits: Int, window: Int) {
        let cal = Calendar.current
        let windowDays = 14
        let windowStart = cal.startOfDay(
            for: cal.date(byAdding: .day, value: -windowDays + 1, to: Date())!
        )

        var bestTitle: String = "—"
        var bestHits = 0

        for h in habits {
            let daysHit = Set(
                (h.logs ?? [])
                    .filter { $0.completed && $0.date >= windowStart }
                    .map { cal.startOfDay(for: $0.date) }
            )

            if daysHit.count > bestHits {
                bestHits = daysHit.count
                bestTitle = h.title
            }
        }

        return (title: bestTitle, hits: bestHits, window: windowDays)
    }

    /// Rough guess of "when you usually check in"
    var typicalCheckInTime: Date {
        let times: [Date] = activeHabits.compactMap { h in
            guard let hour = h.reminderHour,
                  let minute = h.reminderMinute else {
                return nil
            }
            return Calendar.current.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: Date()
            )
        }

        guard !times.isEmpty else {
            return Calendar.current.date(
                bySettingHour: 20,
                minute: 0,
                second: 0,
                of: Date()
            ) ?? Date()
        }

        let cal = Calendar.current
        let minutesArray = times.map { t in
            let comps = cal.dateComponents([.hour, .minute], from: t)
            return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        }

        let avgMins = minutesArray.reduce(0, +) / minutesArray.count
        let avgHour = avgMins / 60
        let avgMinute = avgMins % 60

        return cal.date(
            bySettingHour: avgHour,
            minute: avgMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    // MARK: - Widget sync
    private func pushProgressToWidget() {
        let tc = todayCompletion
        SharedProgressStore.saveToday(done: tc.done, total: tc.total)
    }
}
