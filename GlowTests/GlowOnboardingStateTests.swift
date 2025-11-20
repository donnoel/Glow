import Testing
@testable import Glow

struct GlowOnboardingStateTests {

    @Test
    func starts_on_page_zero_with_correct_total() {
        let state = GlowOnboardingState(totalPages: 4)

        #expect(state.pageIndex == 0)
        #expect(state.totalPages == 4)
        #expect(state.isOnLastPage == false)
        #expect(state.primaryButtonTitle == "Next")
    }

    @Test
    func advances_until_last_page_but_not_beyond() {
        var state = GlowOnboardingState(totalPages: 4)

        state.advance()
        #expect(state.pageIndex == 1)
        #expect(state.isOnLastPage == false)

        state.advance()
        state.advance()
        #expect(state.pageIndex == 3)
        #expect(state.isOnLastPage == true)

        // extra advance should not go past the last page
        state.advance()
        #expect(state.pageIndex == 3)
    }

    @Test
    func primary_button_title_switches_on_last_page() {
        var state = GlowOnboardingState(totalPages: 4)

        #expect(state.primaryButtonTitle == "Next")

        state.advance()
        state.advance()
        state.advance()
        #expect(state.isOnLastPage == true)
        #expect(state.primaryButtonTitle == "Get started")
    }
}
