import Testing
@testable import Glow
import Foundation

@MainActor
struct SharedProgressStoreTests {

    @Test
    func saveToday_writes_expected_keys_and_values() throws {
        // Use the actual app group suite used by SharedProgressStore
        let suiteName = "group.movie.Glow"
        let defaultsOptional = UserDefaults(suiteName: suiteName)
        #expect(defaultsOptional != nil)

        guard let defaults = defaultsOptional else {
            // If the suite can't be created in this environment, bail out early.
            return
        }

        // Clear any existing values for this suite so we get a clean run
        defaults.removePersistentDomain(forName: suiteName)

        let done = 3
        let total = 5
        let bonus = 1

        SharedProgressStore.saveToday(done: done, total: total, bonus: bonus)

        // Core values should be written as expected
        #expect(defaults.integer(forKey: "today_done") == done)
        #expect(defaults.integer(forKey: "today_total") == total)
        #expect(defaults.integer(forKey: "today_bonus") == bonus)

        // Date string should look like yyyy-MM-dd
        let dateString = defaults.string(forKey: "today_date")
        #expect(dateString?.count == "yyyy-MM-dd".count)

        // Stamp should look like a yyyymmdd-style integer in a sane range
        let stamp = defaults.integer(forKey: "today_stamp")
        #expect(stamp >= 19000101)
        #expect(stamp <= 99991231)

        // last_updated should be a positive timestamp
        let lastUpdated = defaults.double(forKey: "last_updated")
        #expect(lastUpdated > 0)
    }

    @Test
    func resetToday_clears_widget_progress_values() throws {
        let suiteName = "group.movie.Glow"
        let defaultsOptional = UserDefaults(suiteName: suiteName)
        #expect(defaultsOptional != nil)

        guard let defaults = defaultsOptional else {
            return
        }

        defaults.removePersistentDomain(forName: suiteName)

        SharedProgressStore.saveToday(done: 4, total: 6, bonus: 2)
        SharedProgressStore.resetToday()

        #expect(defaults.integer(forKey: "today_done") == 0)
        #expect(defaults.integer(forKey: "today_total") == 0)
        #expect(defaults.integer(forKey: "today_bonus") == 0)
        #expect(defaults.integer(forKey: "today_stamp") >= 19000101)
        #expect(defaults.double(forKey: "last_updated") > 0)
    }

    @Test
    func saveToday_skips_timestamp_update_when_progress_is_unchanged() throws {
        let suiteName = "group.movie.Glow"
        let defaultsOptional = UserDefaults(suiteName: suiteName)
        #expect(defaultsOptional != nil)

        guard let defaults = defaultsOptional else {
            return
        }

        defaults.removePersistentDomain(forName: suiteName)

        SharedProgressStore.saveToday(done: 2, total: 4, bonus: 1)
        defaults.set(123, forKey: "last_updated")

        SharedProgressStore.saveToday(done: 2, total: 4, bonus: 1)

        #expect(defaults.double(forKey: "last_updated") == 123)
    }
}
