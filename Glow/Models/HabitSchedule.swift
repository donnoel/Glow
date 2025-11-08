import Foundation

enum Weekday: Int, Codable, CaseIterable, Hashable {
    case sun = 1, mon, tue, wed, thu, fri, sat

    static func from(_ date: Date, calendar: Calendar = .current) -> Weekday {
        let value = calendar.component(.weekday, from: date)
        return Weekday(rawValue: value) ?? .sun
    }
}

struct HabitSchedule: Codable, Equatable {
    enum Kind: String, Codable { case daily, custom }

    var kind: Kind
    var days: Set<Weekday>   // used when kind == .custom

    static let daily = HabitSchedule(kind: .daily, days: Set(Weekday.allCases))
    /// Creates a custom schedule with the provided weekdays.
    static func weekdays(_ days: [Weekday]) -> HabitSchedule { .init(kind: .custom, days: Set(days)) }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        switch kind {
        case .daily:
            return true
        case .custom:
            return days.contains(Weekday.from(date, calendar: calendar))
        }
    }
    
    func isScheduledToday(calendar: Calendar = .current) -> Bool {
        isScheduled(on: Date(), calendar: calendar)
    }
}
