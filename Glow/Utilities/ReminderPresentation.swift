import Foundation

enum ReminderPresentation {
    static func statusText(for habit: Habit) -> String {
        statusText(
            reminderEnabled: habit.reminderEnabled,
            reminderTimeComponents: habit.reminderTimeComponents,
            schedule: habit.schedule,
            isArchived: habit.isArchived
        )
    }

    static func statusText(
        reminderEnabled: Bool,
        reminderTime: Date,
        schedule: HabitSchedule,
        isArchived: Bool
    ) -> String {
        guard reminderEnabled else { return "Reminder off" }

        let timeText = reminderTime.formatted(date: .omitted, time: .shortened)
        let scheduleText = scheduleContextText(for: schedule)
        let base = "Reminder at \(timeText), \(scheduleText)"

        if isArchived {
            return "\(base), paused while archived"
        }
        return base
    }

    static func statusText(
        reminderEnabled: Bool,
        reminderTimeComponents: DateComponents?,
        schedule: HabitSchedule,
        isArchived: Bool
    ) -> String {
        guard reminderEnabled else { return "Reminder off" }
        guard let reminderTimeComponents,
              let date = Calendar.current.date(from: reminderTimeComponents) else {
            return isArchived ? "Reminder on, paused while archived" : "Reminder on"
        }
        return statusText(
            reminderEnabled: reminderEnabled,
            reminderTime: date,
            schedule: schedule,
            isArchived: isArchived
        )
    }

    nonisolated static func scheduleContextText(for schedule: HabitSchedule) -> String {
        SchedulePresentation.reminderContextText(for: schedule)
    }
}

enum SchedulePresentation {
    nonisolated static func summaryText(for schedule: HabitSchedule) -> String {
        switch schedule.kind {
        case .daily:
            return "Every day"
        case .custom:
            let ordered = orderedDays(for: schedule)
            guard !ordered.isEmpty else { return "No days selected" }

            if isWeekdays(ordered) {
                return "Weekdays"
            }
            if isWeekends(ordered) {
                return "Weekends"
            }
            if ordered.count == 1, let only = ordered.first {
                return "Every \(fullWeekdayName(only))"
            }

            let names = ordered.map(shortWeekdayName).joined(separator: ", ")
            return "Every \(names)"
        }
    }

    nonisolated static func reminderContextText(for schedule: HabitSchedule) -> String {
        switch schedule.kind {
        case .daily:
            return "every day"
        case .custom:
            let ordered = orderedDays(for: schedule)
            guard !ordered.isEmpty else { return "custom schedule" }
            let names = ordered.map(shortWeekdayName).joined(separator: ", ")
            return "every \(names)"
        }
    }

    nonisolated static func dueStatusText(
        for schedule: HabitSchedule,
        on referenceDate: Date = Date(),
        isArchived: Bool = false,
        calendar: Calendar = .current
    ) -> String {
        if isArchived {
            return "Archived"
        }

        let today = calendar.startOfDay(for: referenceDate)
        if schedule.isScheduled(on: today, calendar: calendar) {
            return "Due today"
        }

        guard let next = nextDueDate(for: schedule, from: today, includeToday: false, calendar: calendar) else {
            return "No due days selected"
        }

        if calendar.isDateInTomorrow(next) {
            return "Next due tomorrow"
        }

        let dayDiff = calendar.dateComponents([.day], from: today, to: next).day ?? 0
        if dayDiff <= 6 {
            return "Next due \(shortWeekdayName(Weekday.from(next, calendar: calendar)))"
        }
        return "Next due \(next.formatted(date: .abbreviated, time: .omitted))"
    }

    nonisolated static func statusAndSummaryText(
        for schedule: HabitSchedule,
        on referenceDate: Date = Date(),
        isArchived: Bool = false,
        calendar: Calendar = .current
    ) -> String {
        let summary = summaryText(for: schedule)
        let dueStatus = dueStatusText(
            for: schedule,
            on: referenceDate,
            isArchived: isArchived,
            calendar: calendar
        )

        if dueStatus == "No due days selected" {
            return summary
        }
        return "\(dueStatus) - \(summary)"
    }

    nonisolated static func nextDueDate(
        for schedule: HabitSchedule,
        from referenceDate: Date = Date(),
        includeToday: Bool = false,
        calendar: Calendar = .current
    ) -> Date? {
        let start = calendar.startOfDay(for: referenceDate)

        switch schedule.kind {
        case .daily:
            if includeToday {
                return start
            }
            return calendar.date(byAdding: .day, value: 1, to: start)
        case .custom:
            guard !schedule.days.isEmpty else { return nil }

            let lowerBound = includeToday ? 0 : 1
            for offset in lowerBound...13 {
                guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else {
                    continue
                }
                if schedule.isScheduled(on: candidate, calendar: calendar) {
                    return candidate
                }
            }
            return nil
        }
    }

    nonisolated static func customDaysReviewText(for schedule: HabitSchedule) -> String {
        let ordered = orderedDays(for: schedule)
        guard !ordered.isEmpty else { return "No weekdays selected." }
        let names = ordered.map(fullWeekdayName).joined(separator: ", ")
        return "Selected weekdays: \(names)"
    }

    nonisolated private static func orderedDays(for schedule: HabitSchedule) -> [Weekday] {
        Weekday.allCases.filter { schedule.days.contains($0) }
    }

    nonisolated private static func isWeekdays(_ days: [Weekday]) -> Bool {
        days == [.mon, .tue, .wed, .thu, .fri]
    }

    nonisolated private static func isWeekends(_ days: [Weekday]) -> Bool {
        days.count == 2 && Set(days) == Set([.sun, .sat])
    }

    nonisolated private static func shortWeekdayName(_ weekday: Weekday) -> String {
        switch weekday {
        case .sun: return "Sun"
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        }
    }

    nonisolated private static func fullWeekdayName(_ weekday: Weekday) -> String {
        switch weekday {
        case .sun: return "Sunday"
        case .mon: return "Monday"
        case .tue: return "Tuesday"
        case .wed: return "Wednesday"
        case .thu: return "Thursday"
        case .fri: return "Friday"
        case .sat: return "Saturday"
        }
    }
}
