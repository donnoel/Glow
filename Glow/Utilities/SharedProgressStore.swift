import Foundation
import WidgetKit

struct SharedProgressStore {

    static let appGroupID = "group.movie.Glow"
    private static let todayProgressWidgetKind = "TodayProgressWidget"

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

        let now = Date()
        let dayStamp = yyyyMMddStamp(for: now)
        if defaults.integer(forKey: "today_done") == done,
           defaults.integer(forKey: "today_total") == total,
           defaults.integer(forKey: "today_bonus") == bonus,
           defaults.integer(forKey: "today_stamp") == dayStamp,
           defaults.object(forKey: "today_date") != nil {
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
        let todayString = formatter.string(from: now)
        defaults.set(todayString, forKey: "today_date")

        // numeric day-stamp for fast comparisons in the widget
        defaults.set(dayStamp, forKey: "today_stamp")

        // raw timestamp to help the widget detect day rollover
        defaults.set(now.timeIntervalSince1970, forKey: "last_updated")

        print("SharedProgressStore ✅ saved done=\(done) total=\(total) bonus=\(bonus) date=\(todayString) stamp=\(dayStamp) to app group")

        // tell Glow's progress widget to refresh
        WidgetCenter.shared.reloadTimelines(ofKind: todayProgressWidgetKind)
    }

    static func resetToday() {
        saveToday(done: 0, total: 0, bonus: 0)
    }

    private static func yyyyMMddStamp(for date: Date) -> Int {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
}
