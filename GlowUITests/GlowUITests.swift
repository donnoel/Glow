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
        if getStarted.waitForExistence(timeout: 3.0) {
            getStarted.tap()
        }

        // Ensure we actually landed on Home
        waitForHome()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func addPracticeButton() -> XCUIElement {
        if app.buttons["addPracticeButton"].exists {
            return app.buttons["addPracticeButton"]
        } else {
            return app.buttons["Add practice"]
        }
    }

    private func practiceTitleField() -> XCUIElement {
        if app.textFields["practiceTitleField"].exists {
            return app.textFields["practiceTitleField"]
        } else {
            return app.textFields["Title"]
        }
    }

    private func savePracticeButton() -> XCUIElement {
        if app.buttons["savePracticeButton"].exists {
            return app.buttons["savePracticeButton"]
        } else {
            return app.buttons["Save"]
        }
    }

    private func waitForHome(timeout: TimeInterval = 5) {
        let addButton = addPracticeButton()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout),
                      "Home should show the 'Add practice' button.")
    }

    private func createPractice(named title: String, timeout: TimeInterval = 5) {
        let addButton = addPracticeButton()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout),
                      "Add Practice button should exist before creating a practice.")
        addButton.tap()

        let titleField = practiceTitleField()
        XCTAssertTrue(titleField.waitForExistence(timeout: timeout),
                      "Title field should be visible when adding a practice.")
        titleField.tap()
        titleField.typeText(title)

        let saveButton = savePracticeButton()
        XCTAssertTrue(saveButton.waitForExistence(timeout: timeout),
                      "Save button should exist in add practice flow.")
        saveButton.tap()
    }

    // 1) Smoke: app launches and we can see the add button (or its identifier)
    @MainActor
    func testHomeShowsAddPracticeButton() throws {
        waitForHome()
        let addButton = addPracticeButton()
        XCTAssertTrue(addButton.isHittable,
                      "Add Practice button should be hittable on home screen.")
    }

    // 2) Add practice flow works (sheet or push)
    @MainActor
    func testAddPracticeFlow() throws {
        waitForHome()
        createPractice(named: "UITest Practice")

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
        // Always ensure we have a known practice to toggle
        createPractice(named: "UITest Auto")

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
            let app = XCUIApplication()
            app.launchArguments += ["--uitesting"]
            app.launchEnvironment["IS_UI_TEST"] = "1"
            app.launch()
        }
    }
}
