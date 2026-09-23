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
        XCTAssertTrue(app.staticTexts["What should we call you?"].waitForExistence(timeout: 5))
        snap("01-onboarding-name")
        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Alex\n")         // submitting moves on to the goal step
        XCTAssertTrue(app.staticTexts["What's your main goal?"].waitForExistence(timeout: 5))
        snap("02-onboarding-goal")
        tapButton(containing: "Continue")   // goal
        tapButton(containing: "Continue")   // level
        tapButton(containing: "Continue")   // schedule
        snap("03-onboarding-equipment")
        tapButton(containing: "Continue")   // equipment
        tapButton(containing: "Continue")   // body details
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
