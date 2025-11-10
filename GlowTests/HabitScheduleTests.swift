import Testing
@testable import Glow
import Foundation

struct HabitScheduleTests {

    // MARK: - Helpers

    /// Make a date for a specific weekday in the current week
    /// so we can test "isScheduled(on:)" deterministically.
    private func date(for weekday: Weekday, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = Weekday.from(today)

        if todayWeekday == weekday {
            return today
        }

        // find the difference in days to reach the target weekday
        var components = DateComponents()
        var delta = weekday.rawValue - todayWeekday.rawValue
        if delta < 0 {
            delta += 7
        }
        components.day = delta
        return calendar.date(byAdding: components, to: today)!
    }

    private func dailySchedule() -> HabitSchedule {
        HabitSchedule(kind: .daily, days: [])
    }

    private func customSchedule(_ days: [Weekday]) -> HabitSchedule {
        HabitSchedule(kind: .custom, days: Set(days))
    }

    // MARK: - Tests

    @Test
    func daily_is_always_scheduled() throws {
        let schedule = dailySchedule()
        let cal = Calendar.current

        // check several days to prove it's daily
        for offset in 0..<5 {
            let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now))!
            #expect(schedule.isScheduled(on: day))
        }
    }

    @Test
    func custom_is_scheduled_only_on_listed_days() throws {
        let cal = Calendar.current
        let schedule = customSchedule([.mon, .wed, .fri])

        let monday = date(for: .mon, calendar: cal)
        let tuesday = date(for: .tue, calendar: cal)
        let wednesday = date(for: .wed, calendar: cal)
        let friday = date(for: .fri, calendar: cal)

        #expect(schedule.isScheduled(on: monday))
        #expect(!schedule.isScheduled(on: tuesday))
        #expect(schedule.isScheduled(on: wednesday))
        #expect(schedule.isScheduled(on: friday))
    }

    @Test
    func custom_empty_days_is_never_scheduled() throws {
        let schedule = HabitSchedule(kind: .custom, days: [])
        let today = Calendar.current.startOfDay(for: Date())
        #expect(!schedule.isScheduled(on: today))
    }

    @Test
    func weekday_from_date_roundtrips() throws {
        let cal = Calendar.current
        for weekday in Weekday.allCases {
            let d = date(for: weekday, calendar: cal)
            let resolved = Weekday.from(d)
            #expect(resolved == weekday)
        }
    }
}
