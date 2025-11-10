import Foundation

struct SharedProgressStore {
    // 👇 use the exact app group you just created
    static let appGroupID = "group.com.donnoel.GlowShared"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Save today's numbers so the widget can read them.
    static func saveToday(done: Int, total: Int) {
        defaults?.set(done, forKey: "today_done")
        defaults?.set(total, forKey: "today_total")
    }
}
