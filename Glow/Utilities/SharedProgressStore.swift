import Foundation
import WidgetKit

struct SharedProgressStore {

    // 👇 this is your group from earlier
    static let appGroupID = "group.movie.Glow"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Save today's progress for the widget + force a timeline reload.
    /// Widget expects: today_done, today_total, today_date (yyyy-MM-dd)
    static func saveToday(done: Int, total: Int) {
        guard let defaults = sharedDefaults else {
            print("SharedProgressStore ❌ could not open app group defaults: \(appGroupID)")
            return
        }

        // numbers
        defaults.set(done, forKey: "today_done")
        defaults.set(total, forKey: "today_total")

        // date — must match the widget's loadTodayProgress() format
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        defaults.set(todayString, forKey: "today_date")

        print("SharedProgressStore ✅ saved done=\(done) total=\(total) date=\(todayString) to app group")

        // tell widgets to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }
}
