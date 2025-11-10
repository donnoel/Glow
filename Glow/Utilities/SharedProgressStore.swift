import Foundation
import WidgetKit

struct SharedProgressStore {

    // 👇 THIS is your real group
    static let appGroupID = "group.movie.Glow"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func saveToday(done: Int, total: Int) {
        guard let defaults = sharedDefaults else {
            print("SharedProgressStore ❌ could not open app group defaults: \(appGroupID)")
            return
        }

        defaults.set(done, forKey: "today_done")
        defaults.set(total, forKey: "today_total")

        print("SharedProgressStore ✅ saved done=\(done) total=\(total) to app group")

        WidgetCenter.shared.reloadAllTimelines()
    }
}
