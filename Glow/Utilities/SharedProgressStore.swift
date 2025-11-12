import Foundation
import WidgetKit

struct SharedProgressStore {

    // 👇 this is your group from earlier
    static let appGroupID = "group.movie.Glow"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Save today's progress for the widget + force a timeline reload.
    /// Widget expects: today_done, today_total, today_bonus, today_date (yyyy-MM-dd), last_updated (epoch seconds)
    static func saveToday(done: Int, total: Int, bonus: Int = 0) {
        guard let defaults = sharedDefaults else {
            print("SharedProgressStore ❌ could not open app group defaults: \(appGroupID)")
            return
        }

        // numbers
        defaults.set(done, forKey: "today_done")
        defaults.set(total, forKey: "today_total")
        defaults.set(bonus, forKey: "today_bonus")

        // date — keep string for widget compatibility
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        defaults.set(todayString, forKey: "today_date")

        // numeric day-stamp for fast comparisons in the widget
        let dayStamp = yyyyMMddStamp(for: Date())
        defaults.set(dayStamp, forKey: "today_stamp")

        // raw timestamp to help the widget detect day rollover
        defaults.set(Date().timeIntervalSince1970, forKey: "last_updated")

        print("SharedProgressStore ✅ saved done=\(done) total=\(total) bonus=\(bonus) date=\(todayString) stamp=\(dayStamp) to app group")

        // tell widgets to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func yyyyMMddStamp(for date: Date) -> Int {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
}
