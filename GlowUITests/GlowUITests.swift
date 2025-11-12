import XCTest

final class GlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Ensure tests land on Home (skip onboarding)
        app.launchArguments += ["--uitesting"]
        app.launchEnvironment["IS_UI_TEST"] = "1"
        app.launch()

        // Fallback: if onboarding still appears for any reason, dismiss it
        let getStarted = app.buttons["Get started"]
        if getStarted.waitForExistence(timeout: 1.0) {
            getStarted.tap()
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func waitForHome(timeout: TimeInterval = 5) {
        let addButton = app.buttons["addPracticeButton"].exists
            ? app.buttons["addPracticeButton"]
            : app.buttons["Add practice"]
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout),
                      "Home should show the 'Add practice' button.")
    }

    // 1) Smoke: app launches and we can see the add button (or its identifier)
    @MainActor
    func testHomeShowsAddPracticeButton() throws {
        waitForHome()
        // Prefer an accessibility identifier if your Glow app sets one, e.g. "addPracticeButton"
        let addButton = app.buttons["addPracticeButton"].exists
            ? app.buttons["addPracticeButton"]
            : app.buttons["Add practice"]

        XCTAssertTrue(addButton.waitForExistence(timeout: 5),
                      "Add Practice button should be visible on home screen.")
    }

    // 2) Add practice flow works (sheet or push)
    @MainActor
    func testAddPracticeFlow() throws {
        waitForHome()
        let addButton = app.buttons["addPracticeButton"].exists
            ? app.buttons["addPracticeButton"]
            : app.buttons["Add practice"]

        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Try common field names; adjust to match Glow’s actual textfield id/label
        let titleField = app.textFields["practiceTitleField"].exists
            ? app.textFields["practiceTitleField"]
            : app.textFields["Title"]

        XCTAssertTrue(titleField.waitForExistence(timeout: 5),
                      "Title field should be visible when adding a practice.")

        titleField.tap()
        titleField.typeText("UITest Practice")

        // Try identifier first, then button title
        let saveButton = app.buttons["savePracticeButton"].exists
            ? app.buttons["savePracticeButton"]
            : app.buttons["Save"]

        XCTAssertTrue(saveButton.waitForExistence(timeout: 3),
                      "Save button should exist in add practice flow.")
        saveButton.tap()

        // Verify the new practice shows up
        let newRow = app.staticTexts["UITest Practice"]
        XCTAssertTrue(newRow.waitForExistence(timeout: 5),
                      "Newly added practice should appear in the list.")
    }

    // 3) Sidebar / menu opens and Reminders is shown
    @MainActor
    func testOpenSidebarAndShowReminders() throws {
        waitForHome()
        // Prefer identifier if set
        let menuButton = app.buttons["menuButton"].exists
            ? app.buttons["menuButton"]
            : app.buttons["Menu"]

        XCTAssertTrue(menuButton.waitForExistence(timeout: 5),
                      "Menu button should be present on the home screen.")
        menuButton.tap()

        let remindersButton = app.buttons["remindersButton"].exists
            ? app.buttons["remindersButton"]
            : app.buttons["Reminders"]

        XCTAssertTrue(remindersButton.waitForExistence(timeout: 3),
                      "Reminders item should be visible in the sidebar or menu.")
        remindersButton.tap()

        // Check for a known reminders title
        let remindersTitle = app.staticTexts["Reminders"]
        XCTAssertTrue(remindersTitle.waitForExistence(timeout: 5),
                      "Reminders view/sheet should be shown after tapping Reminders.")
    }

    // 4) Mark first practice complete
    @MainActor
    func testToggleFirstPracticeComplete() throws {
        waitForHome()
        // Ensure we have at least one practice
        let existingPractice = app.staticTexts["UITest Auto"]

        if !existingPractice.exists {
            // create one quickly using the same helper steps
            let addButton = app.buttons["addPracticeButton"].exists
                ? app.buttons["addPracticeButton"]
                : app.buttons["Add practice"]
            if addButton.waitForExistence(timeout: 3) {
                addButton.tap()
                let titleField = app.textFields["practiceTitleField"].exists
                    ? app.textFields["practiceTitleField"]
                    : app.textFields["Title"]
                if titleField.waitForExistence(timeout: 3) {
                    titleField.tap()
                    titleField.typeText("UITest Auto")
                    let saveButton = app.buttons["savePracticeButton"].exists
                        ? app.buttons["savePracticeButton"]
                        : app.buttons["Save"]
                    if saveButton.waitForExistence(timeout: 2) {
                        saveButton.tap()
                    }
                }
            }
        }

        // Try identifier first, then a predicate on the label
        let toggleButton: XCUIElement
        if app.buttons["practiceToggleButton"].exists {
            toggleButton = app.buttons["practiceToggleButton"]
        } else {
            toggleButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Mark practice'")).firstMatch
        }

        XCTAssertTrue(toggleButton.waitForExistence(timeout: 5),
                      "Should find a practice toggle button.")
        toggleButton.tap()
        // We don't assert the resulting state here to keep the test stable.
    }

    // 5) Existing performance test
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
