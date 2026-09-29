import Testing
@testable import Glow

@MainActor
struct GlowExtensionsTests {
    @Test
    func habitAccentColorUsesStableIdentifierMapping() {
        let expectations = [
            (id: "", color: "PracticeCoralAccent"),
            (id: "a", color: "PracticeAmberAccent"),
            (id: "b", color: "PracticeMintAccent"),
            (id: "00000000-0000-0000-0000-000000000000", color: "PracticeMintAccent")
        ]

        for expectation in expectations {
            let habit = Habit(id: expectation.id, title: "Test")
            #expect(habit.accentColorName == expectation.color)
        }
    }
}
