import XCTest

/// Drives the main user flows on a simulator and saves screenshots.
/// Screenshots are attached to the test results and, on CI, written to
/// `$SIMULATOR_HOST_HOME/forgefit-screens` so the workflow can upload them.
final class ForgeFitUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    func testOnboardingWorkoutAndTabs() {
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        // Onboarding
        XCTAssertTrue(app.staticTexts["Take your body\nto the peak."].waitForExistence(timeout: 5)
                      || app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Let's Go")).firstMatch.exists)
        snap("00-welcome")
        tapButton(containing: "Let's Go")
        XCTAssertTrue(text(containing: "name?").waitForExistence(timeout: 5))
        snap("01-onboarding-name")
        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        if app.keyboards.element.waitForExistence(timeout: 3) {
            text(containing: "name?").tap()  // tapping outside a field closes the keyboard
            XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 3), "Tapping outside should close the keyboard")
            nameField.tap()
        }
        nameField.typeText("Alex\n")         // submitting moves on to the next question
        XCTAssertTrue(text(containing: "gender?").waitForExistence(timeout: 5))
        tapButton(containing: "Female")
        snap("02-onboarding-gender")
        tapButton(containing: "Continue")   // gender -> age
        XCTAssertTrue(text(containing: "age?").waitForExistence(timeout: 5))
        snap("02b-onboarding-age")
        tapButton(containing: "Continue")   // age -> height
        XCTAssertTrue(text(containing: "height?").waitForExistence(timeout: 5))
        snap("03-onboarding-height")
        tapButton(containing: "Continue")   // height -> weight
        XCTAssertTrue(text(containing: "weight?").waitForExistence(timeout: 5))
        snap("03b-onboarding-weight")
        tapButton(containing: "Continue")   // weight -> goal
        XCTAssertTrue(text(containing: "main goal?").waitForExistence(timeout: 5))
        snap("03c-onboarding-goal")
        tapButton(containing: "Continue")   // goal -> level
        tapButton(containing: "Continue")   // level -> sports
        XCTAssertTrue(text(containing: "favorite sport?").waitForExistence(timeout: 5))
        tapButton(containing: "bodybuilding")
        tapButton(containing: "running")
        snap("03d-onboarding-sports")
        tapButton(containing: "Continue")   // sports -> schedule
        tapButton(containing: "Continue")   // schedule -> equipment
        XCTAssertTrue(text(containing: "equipment").waitForExistence(timeout: 5))
        snap("03e-onboarding-equipment")
        app.swipeUp()
        snap("03f-onboarding-equipment-scrolled")
        tapButton(containing: "Continue")   // equipment -> injuries
        tapButton(containing: "Continue")   // injuries -> plan
        XCTAssertTrue(app.staticTexts["Your plan is ready, Alex!"].waitForExistence(timeout: 10))
        snap("04-onboarding-plan-ready")
        tapButton(containing: "Let's go")

        // Home
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ', Alex'")).firstMatch.exists)
        snap("05-home")

        // Workout
        tapButton(containing: "Start Workout")
        allowNotificationsIfAsked()
        let firstSet = app.buttons["Complete set 1"].firstMatch
        XCTAssertTrue(firstSet.waitForExistence(timeout: 5))
        firstSet.tap()
        XCTAssertTrue(app.staticTexts["REST"].waitForExistence(timeout: 3))
        app.buttons["Complete set 2"].firstMatch.tap()
        snap("06-workout-rest-timer")
        tapButton(containing: "Skip")
        tapButton(containing: "Finish")
        XCTAssertTrue(app.staticTexts["Great work!"].waitForExistence(timeout: 5))
        snap("07-finish-workout")
        tapButton(containing: "Save workout")
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))
        snap("08-home-after-workout")

        // Plans
        app.buttons["Plans"].tap()
        XCTAssertTrue(app.navigationBars["Plans"].waitForExistence(timeout: 5))
        snap("09-plans")
        tapButton(containing: "Generate a plan")
        XCTAssertTrue(app.navigationBars["Generate Plan"].waitForExistence(timeout: 5))
        snap("10-generate-plan")
        app.swipeUp()
        snap("11-generate-equipment")
        app.swipeUp()
        app.swipeUp()
        tapButton(containing: "Generate instantly")
        XCTAssertTrue(app.navigationBars["Your New Plan"].waitForExistence(timeout: 8))
        snap("12-generated-plan")
        tapButton(containing: "Save & make active")
        XCTAssertTrue(app.navigationBars["Plans"].waitForExistence(timeout: 5))
        snap("12b-plans-list")

        // Custom builder + exercise picker
        tapButton(containing: "Build your own")
        XCTAssertTrue(app.navigationBars["Build Plan"].waitForExistence(timeout: 5))
        tapButton(containing: "Add exercises")
        XCTAssertTrue(app.navigationBars["Add Exercises"].waitForExistence(timeout: 5))
        snap("13-exercise-picker")
        tap(app.navigationBars["Add Exercises"].buttons["Cancel"])
        tap(app.navigationBars["Build Plan"].buttons["Cancel"])

        // Coach
        app.buttons["Coach"].tap()
        XCTAssertTrue(app.buttons["Add API key"].waitForExistence(timeout: 5))
        snap("14-coach")

        // Progress + Profile
        app.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        snap("15-progress")
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        snap("16-profile")
        app.swipeUp()
        snap("16b-profile-bottom")
        tapButton(containing: "Gemini connection")
        XCTAssertTrue(app.navigationBars["AI Coach"].waitForExistence(timeout: 5))
        snap("17-ai-settings")
        app.swipeUp()
        snap("17b-ai-models")
    }

    func testCoachKeyboardAndErrors() {
        app = XCUIApplication()
        // An invalid key: the chat opens, and Google's real endpoint rejects the request.
        app.launchArguments = ["-uiTestReset", "-uiTestDemoHistory", "-uiTestAPIKey", "invalid-ui-test-key"]
        app.launch()

        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))
        app.buttons["Coach"].tap()
        let input = app.textViews["coachInput"].exists ? app.textViews["coachInput"] : app.textFields["coachInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))

        // The hide-keyboard button appears while typing and closes the keyboard.
        input.tap()
        let hide = app.buttons["Hide keyboard"]
        XCTAssertTrue(hide.waitForExistence(timeout: 3))
        snap("30-coach-typing")
        hide.tap()
        XCTAssertTrue(hide.waitForNonExistence(timeout: 3), "Hide keyboard should end editing")
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 3), "Tab bar should come back")

        // Tapping outside the field also closes it.
        input.tap()
        XCTAssertTrue(hide.waitForExistence(timeout: 3))
        text(containing: "I'm your coach").tap()
        XCTAssertTrue(hide.waitForNonExistence(timeout: 3), "Tapping outside should end editing")

        // Sending closes the keyboard; the rejected key shows Google's reason.
        input.tap()
        input.typeText("Hey")
        app.buttons["Send"].tap()
        XCTAssertTrue(hide.waitForNonExistence(timeout: 3))
        _ = text(containing: "Google:").waitForExistence(timeout: 25)
        snap("31-coach-error")
    }

    func testProgressWithHistory() {
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestDemoHistory"]
        app.launch()

        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))
        snap("20-home-with-history")
        app.swipeUp()
        snap("20b-home-scrolled")
        app.swipeUp()
        snap("20c-home-bottom")

        app.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        snap("21-progress-overview")
        app.swipeUp()
        snap("22-progress-charts")
        app.swipeUp()
        snap("23-progress-records")

        app.swipeDown()
        app.swipeDown()
        app.buttons["History"].firstMatch.tap()
        snap("24-history")
        let firstSession = app.buttons.matching(NSPredicate(format: "label CONTAINS 'sets'")).firstMatch
        if firstSession.waitForExistence(timeout: 3) {
            firstSession.tap()
            snap("25-session-detail")
        }

        app.buttons["Plans"].tap()
        XCTAssertTrue(app.navigationBars["Plans"].waitForExistence(timeout: 5))
        snap("26a-plans")
        let active = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Active'")).firstMatch
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        active.tap()
        snap("26-plan-detail")
    }

    // MARK: Helpers

    private func text(containing value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)", file: file, line: line)
        element.tap()
    }

    private func tapButton(containing text: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No button containing '\(text)'", file: file, line: line)
        var swipes = 0
        while !button.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        button.tap()
    }

    /// The rest timer asks for notification permission the first time a workout opens.
    private func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }
    }

    private func snap(_ name: String) {
        // Let animations settle before capturing.
        Thread.sleep(forTimeInterval: 0.8)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let dir = URL(fileURLWithPath: home).appendingPathComponent("forgefit-screens")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }
}
