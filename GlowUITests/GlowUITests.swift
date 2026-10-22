import XCTest

final class GlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func launchForHome(resetData: Bool = true) {
        app = XCUIApplication()
        app.launchArguments += ["--uitesting"]
        if resetData {
            app.launchArguments += ["-resetDataForUITests"]
        }
        app.launchEnvironment["IS_UI_TEST"] = "1"
        app.launch()

        let getStarted = app.buttons["Get started"]
        if getStarted.waitForExistence(timeout: 3.0) {
            getStarted.tap()
        }

        waitForHome()
    }

    private func launchForFirstInstallOnboarding() {
        app = XCUIApplication()
        app.launchArguments += ["-resetDataForUITests", "-showOnboardingForUITests"]
        app.launchEnvironment["IS_UI_TEST"] = "1"
        app.launch()
    }

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

    private func openLibrary() {
        let libraryTab = app.tabBars.buttons["Library"].firstMatch
        if libraryTab.waitForExistence(timeout: 5) {
            libraryTab.tap()
            return
        }

        let librarySidebarItem = app.buttons["Library"].firstMatch
        XCTAssertTrue(librarySidebarItem.waitForExistence(timeout: 5),
                      "Library navigation item should be present.")
        librarySidebarItem.tap()
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

    @MainActor
    func testWaterQuickLoggingUndoAndRelaunch() throws {
        launchForHome()
        let progress = app.buttons["waterProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        for (index, ounces) in [12, 21, 24, 28].enumerated() {
            XCTAssertEqual(app.buttons["waterPreset\(index)"].label, "Add \(ounces) fl oz of water")
        }
        app.buttons["waterPreset0"].tap()
        app.buttons["waterPreset3"].tap()
        XCTAssertEqual(progress.value as? String, "40 fl oz of 100 fl oz")
        app.buttons["waterUndo"].tap()
        XCTAssertEqual(progress.value as? String, "12 fl oz of 100 fl oz")
        let todayScreenshot = XCTAttachment(screenshot: app.screenshot())
        todayScreenshot.name = "Water Today"
        todayScreenshot.lifetime = .keepAlways
        add(todayScreenshot)
        app.terminate()
        launchForHome(resetData: false)
        XCTAssertEqual(app.buttons["waterProgress"].value as? String, "12 fl oz of 100 fl oz")
        XCTAssertEqual(app.buttons["waterPreset3"].value as? String, "Last used amount")
    }

    @MainActor
    func testWaterSettingsPersist() throws {
        launchForHome()
        app.buttons["waterSettings"].tap()
        let profile = app.buttons["waterGoalProfile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        profile.tap()
        app.buttons["Female"].tap()
        let goal = app.textFields["waterGoalField"]
        XCTAssertEqual(goal.value as? String, "75")
        let preset = app.textFields["waterPresetField0"]
        preset.doubleTap()
        preset.typeText("10")
        app.buttons["waterSettingsSave"].tap()
        XCTAssertTrue(app.buttons["waterPreset0"].waitForExistence(timeout: 5))
        app.buttons["waterPreset0"].tap()
        XCTAssertEqual(app.buttons["waterProgress"].value as? String, "10 fl oz of 75 fl oz")
        app.terminate()
        launchForHome(resetData: false)
        XCTAssertEqual(app.buttons["waterProgress"].value as? String, "10 fl oz of 75 fl oz")
        app.buttons["waterSettings"].tap()
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        XCTAssertEqual(goal.value as? String, "75")
        XCTAssertEqual(preset.value as? String, "10")
    }

    @MainActor
    func testGentleWaterNudgesAndIndependentPhoneSwitchPersist() throws {
        launchForHome()
        app.buttons["waterSettings"].tap()
        let nudges = app.switches["waterNudgesEnabled"]
        XCTAssertTrue(nudges.waitForExistence(timeout: 5))
        for _ in 0..<3 where !nudges.isHittable { app.swipeUp() }
        XCTAssertEqual(nudges.value as? String, "0")
        nudges.switches.firstMatch.tap()
        XCTAssertEqual(nudges.value as? String, "1")
        XCTAssertFalse(app.buttons["waterNudgeStart"].exists)
        XCTAssertFalse(app.buttons["waterNudgeEnd"].exists)
        app.swipeUp()
        let phone = app.switches["waterPhoneNudgesEnabled"]
        for _ in 0..<3 where !phone.exists || !phone.isHittable { app.swipeUp() }
        XCTAssertTrue(phone.waitForExistence(timeout: 5))
        XCTAssertEqual(phone.value as? String, "1")
        phone.switches.firstMatch.tap()
        XCTAssertEqual(phone.value as? String, "0")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Gentle water nudge settings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["waterSettingsSave"].tap()
        XCTAssertTrue(app.buttons["waterProgress"].waitForExistence(timeout: 5))
        app.terminate()
        launchForHome(resetData: false)
        app.buttons["waterSettings"].tap()
        XCTAssertTrue(nudges.waitForExistence(timeout: 5))
        XCTAssertEqual(nudges.value as? String, "1")
        app.swipeUp()
        for _ in 0..<3 where !phone.exists || !phone.isHittable { app.swipeUp() }
        XCTAssertEqual(phone.value as? String, "0")
        for _ in 0..<3 where !nudges.isHittable { app.swipeDown() }
        nudges.switches.firstMatch.tap()
        XCTAssertEqual(nudges.value as? String, "0")
        app.buttons["waterSettingsSave"].tap()
        XCTAssertTrue(app.buttons["waterProgress"].waitForExistence(timeout: 5))
        app.buttons["waterSettings"].tap()
        XCTAssertTrue(nudges.waitForExistence(timeout: 5))
        XCTAssertEqual(nudges.value as? String, "0")
    }

    @MainActor
    func testMomentumReportPeriodsPreviewAndShare() throws {
        launchForHome()
        createPractice(named: "Read for ten minutes")
        let insights = app.tabBars.buttons["Insights"].firstMatch
        if insights.exists {
            insights.tap()
        } else {
            let showSidebar = app.buttons["Show Sidebar"]
            if showSidebar.exists { showSidebar.tap() }
            let item = app.staticTexts["Insights"].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 5))
            item.tap()
        }
        let report = app.buttons["momentumReport"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        report.tap()
        let title = app.staticTexts["momentumReportTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Weekly momentum")
        XCTAssertTrue(app.staticTexts["Read for ten minutes"].exists)
        app.buttons["momentumReportScope"].tap()
        app.buttons["Active only"].tap()
        app.buttons["momentumReportScope"].tap()
        app.buttons["All habits"].tap()
        for period in ["Monthly", "Quarterly", "Annual", "Lifetime", "Weekly"] {
            app.buttons["momentumReportPeriod"].tap()
            app.buttons[period].tap()
            XCTAssertEqual(title.label, "\(period) momentum")
        }
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Momentum report preview"
        preview.lifetime = .keepAlways
        add(preview)
        app.buttons["shareMomentumReport"].tap()
        let sharing = XCUIApplication(bundleIdentifier: "com.apple.SharingUIService")
        let moreActions = sharing.cells["View More"]
        let localMoreActions = app.cells["View More"]
        let copy = sharing.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        let localCopy = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        // A fresh simulator may still be starting the remote share service.
        let shareDeadline = Date().addingTimeInterval(60)
        var copyIsAvailable = false
        repeat {
            if copy.waitForExistence(timeout: 1) || localCopy.exists {
                copyIsAvailable = true
                break
            }
            if moreActions.exists && moreActions.isHittable {
                moreActions.tap()
            } else if localMoreActions.exists && localMoreActions.isHittable {
                localMoreActions.tap()
            }
        } while Date() < shareDeadline
        XCTAssertTrue(copyIsAvailable, "Native share sheet should offer the report as text. \(sharing.debugDescription) \(app.debugDescription)")
        let share = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        share.name = "Momentum report share sheet"
        share.lifetime = .keepAlways
        add(share)
    }

    @MainActor
    func testWaterCustomAmountEditAndInsights() throws {
        launchForHome()
        app.buttons["waterCustom"].tap()
        let amount = app.textFields["waterAmountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("15")
        app.buttons["waterAmountSave"].tap()
        let progress = app.buttons["waterProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.value as? String, "15 fl oz of 100 fl oz")
        progress.tap()
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "15 fl oz,")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.doubleTap()
        amount.typeText("12")
        app.buttons["waterAmountSave"].tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertEqual(progress.value as? String, "12 fl oz of 100 fl oz")
        let insights = app.tabBars.buttons["Insights"].firstMatch
        if insights.exists {
            insights.tap()
        } else {
            let showSidebar = app.buttons["Show Sidebar"]
            if showSidebar.exists { showSidebar.tap() }
            let sidebarItem = app.staticTexts["Insights"].firstMatch
            XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5))
            sidebarItem.tap()
        }
        XCTAssertTrue(app.staticTexts["waterReportStory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["waterReportStory"].label.contains("water logged on 1"))
        let insightsScreenshot = XCTAttachment(screenshot: app.screenshot())
        insightsScreenshot.name = "Water Insights"
        insightsScreenshot.lifetime = .keepAlways
        add(insightsScreenshot)
    }

    // 1) Smoke: app launches and we can see the add button (or its identifier)
    @MainActor
    func testHomeShowsAddPracticeButton() throws {
        launchForHome()
        waitForHome()
        let addButton = addPracticeButton()
        XCTAssertTrue(addButton.isHittable,
                      "Add Practice button should be hittable on home screen.")
    }

    @MainActor
    func testIPadSidebarVisibilitySurvivesRelaunch() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad-only sidebar")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        launchForHome(resetData: false)

        let library = app.staticTexts["Library"].firstMatch
        let toggle = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Hide Sidebar", "Show Sidebar"])
        ).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if !library.isHittable {
            toggle.tap()
        }
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertTrue(library.isHittable)

        toggle.tap()
        XCTAssertTrue(library.waitForNonExistence(timeout: 5))
        app.terminate()
        app.launch()
        waitForHome()
        XCTAssertFalse(library.isHittable, "Closed sidebar should remain closed after relaunch")

        toggle.tap()
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        waitForHome()
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertTrue(library.isHittable, "Open sidebar should remain open after relaunch")
    }

    @MainActor
    func testAddPracticeFlow() throws {
        launchForHome()
        waitForHome()
        createPractice(named: "UITest Practice")

        // Verify the new practice shows up
        let newRow = app.staticTexts["UITest Practice"]
        XCTAssertTrue(newRow.waitForExistence(timeout: 5),
                      "Newly added practice should appear in the list.")
    }

    @MainActor
    func testTodayRowExposesDetailsAccessibilityAction() throws {
        launchForHome()
        waitForHome()
        createPractice(named: "UITest Details")

        let detailsButton = app.buttons["Open details for UITest Details"]
        XCTAssertTrue(detailsButton.waitForExistence(timeout: 5),
                      "Today row should expose an accessibility action for opening habit details.")
    }

    // 3) Sidebar / menu opens and Reminders is shown
    @MainActor
    func testOpenSidebarAndShowReminders() throws {
        launchForHome()
        waitForHome()
        openLibrary()

        let remindersButton = app.buttons["Manage reminders"].exists
            ? app.buttons["Manage reminders"]
            : app.staticTexts["Manage reminders"]

        XCTAssertTrue(remindersButton.waitForExistence(timeout: 5),
                      "Reminders item should be visible in Library.")
        remindersButton.tap()

        // Check for a known reminders title
        let remindersTitle = app.staticTexts["Reminders"]
        XCTAssertTrue(remindersTitle.waitForExistence(timeout: 5),
                      "Reminders view/sheet should be shown after tapping Reminders.")
    }

    // 4) Mark first practice complete
    @MainActor
    func testToggleFirstPracticeComplete() throws {
        launchForHome()
        waitForHome()
        // Always ensure we have a known practice to toggle
        createPractice(named: "UITest Auto")

        // Try identifier first, then a predicate on the label
        let toggleButton: XCUIElement
        if app.buttons["practiceToggleButton"].exists {
            toggleButton = app.buttons["practiceToggleButton"]
        } else {
            toggleButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Mark' AND label CONTAINS[c] 'done today'")
            ).firstMatch
        }

        XCTAssertTrue(toggleButton.waitForExistence(timeout: 5),
                      "Should find a practice toggle button.")
        toggleButton.tap()

        let completedToggle = app.buttons["Mark UITest Auto not done today"]
        XCTAssertTrue(completedToggle.waitForExistence(timeout: 5),
                      "Toggled practice should expose the completed-state accessibility label.")

        let undoButton = app.buttons["Undo"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5),
                      "Completing a practice should show the undo affordance.")
    }

    // 5) First-install onboarding can complete into Home
    @MainActor
    func testFirstInstallOnboardingCanCompleteToHome() throws {
        launchForFirstInstallOnboarding()

        let welcomeTitle = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Welcome to Glow")
        ).firstMatch
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5),
                      "Fresh install should start on the Glow onboarding.")

        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5),
                      "Onboarding should show a Next button.")
        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Add what matters"].waitForExistence(timeout: 5))

        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Stay in control"].waitForExistence(timeout: 5))

        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Always within reach"].waitForExistence(timeout: 5))

        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5),
                      "Last onboarding page should show Get started.")
        getStarted.tap()

        waitForHome()
    }

    // 6) Existing performance test
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let measuredApp = XCUIApplication()
            measuredApp.launchArguments += ["--uitesting", "-resetDataForUITests"]
            measuredApp.launchEnvironment["IS_UI_TEST"] = "1"
            measuredApp.launch()
        }
    }
}
