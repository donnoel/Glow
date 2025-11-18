import Foundation
import SwiftData
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    
    // MARK: - Source of truth
    @Published private(set) var todayStartOfDay: Date
    @Published private(set) var habits: [Habit] = []
    
    // MARK: - Derived (materialized)
    @Published private(set) var activeHabits: [Habit] = []
    @Published private(set) var archivedHabits: [Habit] = []
    @Published private(set) var scheduledTodayHabits: [Habit] = []
    @Published private(set) var completedToday: [Habit] = []
    @Published private(set) var dueButNotDoneToday: [Habit] = []
    @Published private(set) var notDueToday: [Habit] = []
    @Published private(set) var bonusCompletedToday: [Habit] = []
    @Published private(set) var todayCompletion: (done: Int, total: Int, percent: Double) = (0, 0, 0)
    @Published private(set) var isTodayComplete: Bool = false
    @Published private(set) var globalStreak: (current: Int, best: Int) = (0, 0)
    @Published private(set) var mostConsistentHabit: (title: String, hits: Int, window: Int) = ("—", 0, 14)
    @Published private(set) var typicalCheckInTime: Date = Date()
    @Published private(set) var recentActiveDays: Int = 0          // days with ≥1 completion in the last 7 days
    @Published private(set) var lifetimeActiveDays: Int = 0        // distinct days with any completion
    @Published private(set) var lifetimeCompletions: Int = 0       // total completed logs across all time
    
    // MARK: - Init
    init(today: Date = Calendar.current.startOfDay(for: Date())) {
        self.todayStartOfDay = today
        recalcDerived()
    }
    
    // MARK: - Inputs
    func updateHabits(_ habits: [Habit]) {
        self.habits = habits
        recalcDerived()
        // when habits change, push real numbers to the widget
        pushProgressToWidget()
    }
    
    func advanceToToday(_ date: Date) {
        self.todayStartOfDay = Calendar.current.startOfDay(for: date)
        recalcDerived()
        // when the day rolls over, push fresh numbers
        pushProgressToWidget()
    }
    
    // MARK: - "You" summaries (moved from HomeView)
    
    /// All logs, flattened from all habits.
    private var allLogs: [HabitLog] {
        habits.compactMap { $0.logs }.flatMap { $0 }
    }
    
    private func recalcDerived() {
        let cal = Calendar.current
        let today = todayStartOfDay
        
        // 1) split active vs archived
        let active = habits.filter { !$0.isArchived }
        let archived = habits.filter { $0.isArchived }
        
        // 2) scheduled today
        let scheduled = active
            .filter { $0.schedule.isScheduled(on: today) }
            .sorted { $0.sortOrder < $1.sortOrder }
        
        // 3) completed today (scheduled)
        let completedScheduled = scheduled.filter { habit in
            (habit.logs ?? []).contains { log in
                cal.startOfDay(for: log.date) == today && log.completed
            }
        }
        
        // 4) due but not done (scheduled but no completed log today)
        let dueNotDone = scheduled.filter { habit in
            !(habit.logs ?? []).contains { log in
                cal.startOfDay(for: log.date) == today && log.completed
            }
        }
        
        // 5) not due today (active but not scheduled)
        let notDue = active
            .filter { !$0.schedule.isScheduled(on: today) }
            .sorted { $0.sortOrder < $1.sortOrder }
        
        // 6) bonus completions (not scheduled but completed today)
        let bonus = notDue.filter { habit in
            (habit.logs ?? []).contains { log in
                cal.startOfDay(for: log.date) == today && log.completed
            }
        }
        
        // 7) hero numbers
        let totalScheduled = scheduled.count
        let doneScheduled = completedScheduled.count
        let bonusCount = bonus.count
        
        let percentValue: Double
        if totalScheduled == 0 {
            percentValue = bonusCount == 0 ? 0.0 : Double(bonusCount)
        } else {
            percentValue = Double(doneScheduled + bonusCount) / Double(totalScheduled)
        }
        
        // 8) global streak + activity summaries (any habit per day)
        let completedLogs = allLogs.filter { $0.completed }
        let groupedByDay = Dictionary(grouping: completedLogs) {
            cal.startOfDay(for: $0.date)
        }
        let synthetic: [HabitLog] = groupedByDay.keys.map { day in
            HabitLog(date: day, completed: true, habit: Habit.placeholder)
        }
        let streak = StreakEngine.computeStreaks(logs: synthetic)
        
        // lifetime summaries
        let lifetimeDaysWithActivity = groupedByDay.keys.count
        let lifetimeCompletionsCount = completedLogs.count
        
        // last 7 days with at least one completion (including today)
        let recentDaysWithActivity: Int
        if let windowStart = cal.date(byAdding: .day, value: -6, to: today) {
            var count = 0
            for offset in 0..<7 {
                if let d = cal.date(byAdding: .day, value: offset, to: windowStart) {
                    let day = cal.startOfDay(for: d)
                    if groupedByDay.keys.contains(day) {
                        count += 1
                    }
                }
            }
            recentDaysWithActivity = count
        } else {
            recentDaysWithActivity = 0
        }
        
        // 9) most consistent (14d)
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
        
        // 10) typical check-in time (same logic as before)
        let times: [Date] = active.compactMap { h in
            guard let hour = h.reminderHour,
                  let minute = h.reminderMinute else {
                return nil
            }
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
        }
        let typical: Date
        if times.isEmpty {
            typical = cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        } else {
            let minutesArray = times.map { t in
                let comps = cal.dateComponents([.hour, .minute], from: t)
                return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
            let avgMins = minutesArray.reduce(0, +) / minutesArray.count
            let avgHour = avgMins / 60
            let avgMinute = avgMins % 60
            typical = cal.date(bySettingHour: avgHour, minute: avgMinute, second: 0, of: Date()) ?? Date()
        }
        
        // publish
        self.activeHabits = active
        self.archivedHabits = archived
        self.scheduledTodayHabits = scheduled
        self.completedToday = completedScheduled
        self.dueButNotDoneToday = dueNotDone
        self.notDueToday = notDue
        self.bonusCompletedToday = bonus
        self.todayCompletion = (doneScheduled, totalScheduled, percentValue)
        self.isTodayComplete = totalScheduled > 0 && doneScheduled >= totalScheduled
        self.globalStreak = (streak.current, streak.best)
        self.mostConsistentHabit = (bestTitle, bestHits, windowDays)
        self.typicalCheckInTime = typical
        self.recentActiveDays = recentDaysWithActivity
        self.lifetimeActiveDays = lifetimeDaysWithActivity
        self.lifetimeCompletions = lifetimeCompletionsCount
    }
    
    // MARK: - Widget sync
    private func pushProgressToWidget() {
        let tc = todayCompletion
        let bonus = bonusCompletedToday.count
        SharedProgressStore.saveToday(done: tc.done, total: tc.total, bonus: bonus)
    }
}
