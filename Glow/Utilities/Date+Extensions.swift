import Foundation

extension Date {
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
    
    static func todayStart(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: Date())
    }
}
