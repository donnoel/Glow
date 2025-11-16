import Testing
@testable import Glow
import Foundation

@MainActor
struct HomeViewModelTests {

    // MARK: - Helpers

    private func dailySchedule() -> HabitSchedule {
        HabitSchedule(kind: .daily, days: [])
    }

    private func customSchedule(_ days: [Weekday]) -> HabitSchedule {
        HabitSchedule(kind: .custom, days: Set(days))
    }

    /// Make a habit with the fields we actually care about for HomeViewModel
    private func makeHabit(
        title: String,
        schedule: HabitSchedule,
        isArchived: Bool = false,
        reminderEnabled: Bool = false,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        sortOrder: Int = 0,
        logs: [HabitLog] = []
    ) -> Habit {
        let habit = Habit(
            title: title,
            createdAt: .now,
            isArchived: isArchived,
            schedule: schedule,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            iconName: "checkmark.circle",
            sortOrder: sortOrder
        )
        // attach logs
        habit.logs = logs
        return habit
    }

    /// Make a completed log for a specific day (startOfDay)
    private func makeLog(on date: Date, completed: Bool = true, habit: Habit? = nil) -> HabitLog {
        let log = HabitLog(date: date, completed: completed, habit: habit)
        return log
    }

    /// Handy "today" at start of day
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Tests

    @Test
    func activeHabits_excludes_archived() async throws {
        let vm = HomeViewModel(today: today)

        let h1 = makeHabit(title: "Keep", schedule: dailySchedule(), isArchived: false)
        let h2 = makeHabit(title: "Archived", schedule: dailySchedule(), isArchived: true)

        vm.updateHabits([h1, h2])

        #expect(vm.activeHabits.count == 1)
        #expect(vm.activeHabits.first?.title == "Keep")
        #expect(vm.archivedHabits.count == 1)
    }

    @Test
    func scheduledTodayHabits_filters_by_schedule_for_today() async throws {
        let vm = HomeViewModel(today: today)

        // daily -> should be scheduled
        let daily = makeHabit(title: "Daily", schedule: dailySchedule(), sortOrder: 0)

        // figure out what today is
        let todayWeekday = Weekday.from(today)

        // this one should be in
        let customToday = makeHabit(
            title: "CustomToday",
            schedule: customSchedule([todayWeekday]),
            sortOrder: 1
        )

        // pick ANY weekday that is not today, so the test is stable
        let otherWeekday = Weekday.allCases.first { $0 != todayWeekday }!
        let customNotToday = makeHabit(
            title: "CustomNo",
            schedule: customSchedule([otherWeekday]),
            sortOrder: 2
        )

        vm.updateHabits([daily, customToday, customNotToday])

        let scheduled = vm.scheduledTodayHabits

        // should contain daily and the custom-for-today
        #expect(scheduled.contains(where: { $0.title == "Daily" }))
        #expect(scheduled.contains(where: { $0.title == "CustomToday" }))

        // should NOT contain the one explicitly scheduled for a different weekday
        #expect(!scheduled.contains(where: { $0.title == "CustomNo" }))

        // and still ordered by sortOrder
        #expect(scheduled.first?.sortOrder == 0)
    }

    @Test
    func completedToday_picks_logs_matching_today() async throws {
        let vm = HomeViewModel(today: today)

        let h1 = makeHabit(title: "DoneToday", schedule: dailySchedule())
        let h2 = makeHabit(title: "NotDone", schedule: dailySchedule())

        // attach logs
        h1.logs = [makeLog(on: today, completed: true, habit: h1)]
        h2.logs = [] // none

        vm.updateHabits([h1, h2])

        #expect(vm.completedToday.count == 1)
        #expect(vm.completedToday.first?.title == "DoneToday")
    }

    @Test
    func dueButNotDoneToday_excludes_completedToday() async throws {
        let vm = HomeViewModel(today: today)

        let done = makeHabit(title: "Done", schedule: dailySchedule())
        done.logs = [makeLog(on: today, completed: true, habit: done)]

        let due = makeHabit(title: "Due", schedule: dailySchedule()) // daily, no log

        // pick ANY weekday that is not today, so this habit is never scheduled "today"
        let todayWeekday = Weekday.from(today)
        let otherWeekday = Weekday.allCases.first { $0 != todayWeekday }!
        let notToday = makeHabit(
            title: "NotToday",
            schedule: customSchedule([otherWeekday])
        )

        vm.updateHabits([done, due, notToday])

        // dueButNotDoneToday should only contain "Due"
        #expect(vm.dueButNotDoneToday.count == 1)
        #expect(vm.dueButNotDoneToday.first?.title == "Due")
    }

    @Test
    func bonusCompletedToday_is_for_not_scheduled_today_but_done_today() async throws {
        let vm = HomeViewModel(today: today)

        // This one is NOT scheduled today
        let notScheduled = makeHabit(title: "Extra", schedule: customSchedule([]))
        notScheduled.logs = [makeLog(on: today, completed: true, habit: notScheduled)]

        // This one is scheduled today and done
        let scheduled = makeHabit(title: "Normal", schedule: dailySchedule())
        scheduled.logs = [makeLog(on: today, completed: true, habit: scheduled)]

        vm.updateHabits([notScheduled, scheduled])

        #expect(vm.bonusCompletedToday.count == 1)
        #expect(vm.bonusCompletedToday.first?.title == "Extra")
    }

    @Test
    func todayCompletion_handles_bonus_and_can_exceed_100_percent() async throws {
        let vm = HomeViewModel(today: today)

        // scheduled + done
        let scheduledDone = makeHabit(title: "ScheduledDone", schedule: dailySchedule())
        scheduledDone.logs = [makeLog(on: today, completed: true, habit: scheduledDone)]

        // not scheduled but done -> bonus
        let bonus = makeHabit(title: "Bonus", schedule: customSchedule([]))
        bonus.logs = [makeLog(on: today, completed: true, habit: bonus)]

        vm.updateHabits([scheduledDone, bonus])

        let stats = vm.todayCompletion
        #expect(stats.done == 1)
        #expect(stats.total == 1)
        #expect(stats.percent == 2.0) // 1 scheduled done + 1 bonus
    }

    @Test
    func todayCompletion_when_nothing_scheduled_uses_bonus_as_percent() async throws {
        let vm = HomeViewModel(today: today)

        // not scheduled but done
        let bonus = makeHabit(title: "BonusOnly", schedule: customSchedule([]))
        bonus.logs = [makeLog(on: today, completed: true, habit: bonus)]

        vm.updateHabits([bonus])

        let stats = vm.todayCompletion
        #expect(stats.total == 0)
        #expect(stats.done == 0) // because nothing was scheduled
        #expect(stats.percent == 1.0) // 1 bonus -> percent == Double(bonusCount)
    }

    @Test
    func globalStreak_counts_any_completed_habit_per_day() async throws {
        let vm = HomeViewModel(today: today)

        let h1 = makeHabit(title: "A", schedule: dailySchedule())
        let h2 = makeHabit(title: "B", schedule: dailySchedule())

        // yesterday and today completions across 2 habits
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        h1.logs = [makeLog(on: today, completed: true, habit: h1)]
        h2.logs = [makeLog(on: yesterday, completed: true, habit: h2)]

        vm.updateHabits([h1, h2])

        let streaks = vm.globalStreak
        #expect(streaks.current >= 2) // yesterday + today
        #expect(streaks.best >= streaks.current)
    }

    @Test
    func typicalCheckInTime_averages_enabled_reminders() async throws {
        let vm = HomeViewModel(today: today)

        // 8pm
        let h1 = makeHabit(
            title: "Evening",
            schedule: dailySchedule(),
            reminderEnabled: true,
            reminderHour: 20,
            reminderMinute: 0
        )

        // 6pm
        let h2 = makeHabit(
            title: "Earlier",
            schedule: dailySchedule(),
            reminderEnabled: true,
            reminderHour: 18,
            reminderMinute: 0
        )

        vm.updateHabits([h1, h2])

        let t = vm.typicalCheckInTime
        let comps = Calendar.current.dateComponents([.hour], from: t)

        // average of 18 and 20 -> 19
        #expect(comps.hour == 19)
    }

    @Test
    func typicalCheckInTime_falls_back_to_8pm_when_no_reminders() async throws {
        let vm = HomeViewModel(today: today)

        let h1 = makeHabit(title: "No reminder", schedule: dailySchedule(), reminderEnabled: false)
        vm.updateHabits([h1])

        let t = vm.typicalCheckInTime
        let comps = Calendar.current.dateComponents([.hour, .minute], from: t)

        #expect(comps.hour == 20)
        #expect(comps.minute == 0)
    }

    @Test
    func advanceToToday_updates_the_current_day_anchor() async throws {
        let vm = HomeViewModel(today: today)

        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        vm.advanceToToday(tomorrow)

        #expect(vm.todayStartOfDay == cal.startOfDay(for: tomorrow))
    }
}
