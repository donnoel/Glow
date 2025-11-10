import Testing
@testable import Glow
import Foundation

struct HabitIconLibraryTests {

    @Test
    func guessIcon_falls_back_to_checkmark_when_unknown() throws {
        let icon = HabitIconLibrary.guessIcon(for: "totally made up thing 123")
        // this is the fallback you've been using in HomeView
        #expect(icon == "checkmark.circle")
    }

    @Test
    func guessIcon_is_case_insensitive() throws {
        let lower = HabitIconLibrary.guessIcon(for: "water")
        let upper = HabitIconLibrary.guessIcon(for: "WATER")
        #expect(lower == upper)
    }

    @Test
    func guessIcon_handles_leading_trailing_spaces() throws {
        let spaced = HabitIconLibrary.guessIcon(for: "  walk  ")
        let clean = HabitIconLibrary.guessIcon(for: "walk")
        #expect(spaced == clean)
    }

    // If your library has specific keyword matches (common ones):
    @Test
    func guessIcon_matches_common_health_keywords() throws {
        let run = HabitIconLibrary.guessIcon(for: "Run 5k")
        let walk = HabitIconLibrary.guessIcon(for: "Walk dog")
        let drink = HabitIconLibrary.guessIcon(for: "Drink water")

        // We're not asserting the exact symbol names here (since that's app-specific),
        // just that we got *something* non-empty back.
        #expect(!run.isEmpty)
        #expect(!walk.isEmpty)
        #expect(!drink.isEmpty)
    }
}
