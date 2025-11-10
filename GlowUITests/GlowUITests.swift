//
//  GlowUITests.swift
//  GlowUITests
//
//  Created by Don Noel on 10/29/25.
//

import XCTest

final class GlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // 1) Smoke: app launches and we can see the add button
    @MainActor
    func testHomeShowsAddPracticeButton() throws {
        // the HomeView's add button has accessibilityLabel("Add practice")
        let addButton = app.buttons["Add practice"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should be visible on home")
    }

    // 2) Add practice flow works
    @MainActor
    func testAddPracticeFlow() throws {
        let addButton = app.buttons["Add practice"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // the sheet has a TextField("Title")
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should be visible in add sheet")
        titleField.tap()
        titleField.typeText("UITest Practice")

        // tap Save in the navigation bar
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        // after saving, the new practice row should appear somewhere in the list
        // we can look for the text we just added
        let newRow = app.staticTexts["UITest Practice"]
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Newly added practice should appear in the list")
    }

    // 3) Sidebar opens and Reminders can be shown
    @MainActor
    func testOpenSidebarAndShowReminders() throws {
        // menu button uses accessibilityLabel("Menu") in HomeView
        let menuButton = app.buttons["Menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Menu button should be present")
        menuButton.tap()

        // in the sidebar, there's a button labeled "Reminders"
        let remindersButton = app.buttons["Reminders"]
        XCTAssertTrue(remindersButton.waitForExistence(timeout: 3), "Reminders item should be visible in sidebar")
        remindersButton.tap()

        // the RemindersView currently presents as a sheet; assert the word "Reminders" exists somewhere
        // (adjust this if your RemindersView has a different title)
        let remindersTitle = app.staticTexts["Reminders"]
        XCTAssertTrue(remindersTitle.waitForExistence(timeout: 5), "Reminders sheet should be shown")
    }

    // 4) Mark first practice complete from Home
    // This relies on HabitRowGlass exposing the button with an accessibility label
    @MainActor
    func testToggleFirstPracticeComplete() throws {
        // make sure we have at least one practice; if none, add one quickly
        let anyRow = app.staticTexts["UITest Auto"]
        if !anyRow.exists {
            // add a quick practice
            let addButton = app.buttons["Add practice"]
            if addButton.waitForExistence(timeout: 2) {
                addButton.tap()
                let titleField = app.textFields["Title"]
                if titleField.waitForExistence(timeout: 2) {
                    titleField.tap()
                    titleField.typeText("UITest Auto")
                    app.buttons["Save"].tap()
                }
            }
        }

        // find the first toggle button in the list
        // HabitRowGlass sets accessibility labels like "Mark practice complete" / "Mark practice incomplete"
        let completeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Mark practice'"))
            .firstMatch
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5), "Should find a practice toggle button")
        completeButton.tap()
        // no hard assert on result view here; just ensuring the button is tappable without a crash
    }

    // existing performance test can stay
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
