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
        // The celebration summary slides up after saving.
        XCTAssertTrue(text(containing: "WORKOUT SAVED").waitForExistence(timeout: 8))
        snap("07b-workout-summary")
        tap(app.buttons["Done"])
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
        XCTAssertTrue(app.buttons["Start weekly check-in"].waitForExistence(timeout: 5), "Check-in card should show with history and a key")
        snap("29-home-checkin")
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

    func testTrainingFeatures() {
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestDemoHistory"]
        app.launch()

        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(containing: "week streak").waitForExistence(timeout: 5))
        snap("50-home-streak-nutrition")

        // Workout: suggestions from last time's numbers.
        tapButton(containing: "Start Workout")
        allowNotificationsIfAsked()
        XCTAssertTrue(text(containing: "Today:").waitForExistence(timeout: 5), "Progression suggestion should show")
        snap("51-workout-suggestion")
        app.buttons["Use suggestion"].firstMatch.tap()

        let options = app.buttons["Exercise options"].firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        if app.buttons["Add warm-up sets"].waitForExistence(timeout: 3) {
            app.buttons["Add warm-up sets"].tap()
            XCTAssertTrue(app.buttons["Complete warm-up set"].firstMatch.waitForExistence(timeout: 3))
            snap("52-warmups")
        } else {
            app.tap()
        }

        options.tap()
        if app.buttons["Plate calculator"].waitForExistence(timeout: 3) {
            app.buttons["Plate calculator"].tap()
            XCTAssertTrue(app.navigationBars["Plate Calculator"].waitForExistence(timeout: 5))
            snap("53-plate-calculator")
            tap(app.navigationBars["Plate Calculator"].buttons["Done"])
        } else {
            app.tap()
        }

        options.tap()
        tap(app.buttons["How to do it"])
        XCTAssertTrue(text(containing: "REP TEMPO").waitForExistence(timeout: 5))
        snap("54-exercise-guide")
        tap(app.navigationBars["How to"].buttons["Done"])

        options.tap()
        tap(app.buttons["Swap exercise"])
        XCTAssertTrue(text(containing: "Alternatives").waitForExistence(timeout: 5) || app.staticTexts["ALTERNATIVES"].exists)
        snap("55-swap-exercise")
        tap(app.buttons["Cancel"])

        options.tap()
        tap(app.buttons["Superset with next"])
        XCTAssertTrue(text(containing: "SUPERSET A").waitForExistence(timeout: 3))
        snap("56-superset")

        // RPE on the first working set.
        let setOptions = app.buttons.matching(NSPredicate(format: "label == 'Set 1 options'")).firstMatch
        if setOptions.waitForExistence(timeout: 3) {
            setOptions.tap()
            if app.buttons["RPE (effort)"].waitForExistence(timeout: 3) {
                app.buttons["RPE (effort)"].tap()
                let rpe = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '8 ·'")).firstMatch
                if rpe.waitForExistence(timeout: 3) { rpe.tap() } else { app.tap() }
            } else {
                app.tap()
            }
        }

        // Finishing a set in a superset sends you straight to the partner exercise.
        app.buttons["Complete set 1"].firstMatch.tap()
        XCTAssertTrue(text(containing: "Superset →").waitForExistence(timeout: 3))
        snap("57-superset-next")

        tapButton(containing: "Finish")
        tapButton(containing: "Save workout")
        XCTAssertTrue(text(containing: "WORKOUT SAVED").waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Share workout"].waitForExistence(timeout: 8))
        snap("58-workout-summary")
        app.swipeUp()
        snap("58b-workout-summary-share")
        tap(app.buttons["Done"])

        // Badges
        app.buttons["Progress"].tap()
        tapButton(containing: "Badges")
        XCTAssertTrue(app.navigationBars["Badges"].waitForExistence(timeout: 5))
        snap("59-badges")

        // Nutrition: add a meal by hand.
        app.buttons["Home"].tap()
        XCTAssertTrue(text(containing: "This week").waitForExistence(timeout: 5))
        app.swipeUp()   // bring the nutrition card clear of the floating tab bar
        tapButton(containing: "calories today")
        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 5))
        snap("60-nutrition")
        tapButton(containing: "Add manually")
        let name = app.textFields["mealName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Protein shake")
        snap("61-meal-editor")
        tapButton(containing: "Save meal")
        XCTAssertTrue(text(containing: "Protein shake").waitForExistence(timeout: 5))
        snap("62-nutrition-added")

        // Reminders
        app.buttons["Profile"].tap()
        tapButton(containing: "Reminders")
        let toggle = app.switches["Workout reminders"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        allowNotificationsIfAsked()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5), "Turning reminders on shows the time picker")
        snap("63-reminders")
    }

    func testAccountScreens() {
        app = XCUIApplication()
        // A made-up Supabase project: the account screens appear and requests fail fast.
        app.launchArguments = ["-uiTestReset", "-SupabaseURL", "https://forgefit-ui-test.invalid",
                               "-SupabaseKey", "sb_publishable_ui_test"]
        app.launch()

        XCTAssertTrue(app.buttons["I have an account"].waitForExistence(timeout: 5))
        snap("40-welcome-account")
        let haveAccount = app.buttons["I have an account"]
        haveAccount.tap()
        let logInTitle = text(containing: "Log in to bring")
        // On a just-booted simulator the first tap can be dropped (seen once on CI); try once more.
        if !logInTitle.waitForExistence(timeout: 5) && haveAccount.isHittable {
            haveAccount.tap()
        }
        XCTAssertTrue(logInTitle.waitForExistence(timeout: 5))
        snap("41-log-in")

        let email = app.textFields["authEmail"]
        email.tap()
        email.typeText("alex@example.com")
        let password = app.secureTextFields["authPassword"]
        password.tap()
        password.typeText("secret123")
        tapButton(containing: "Log in")
        let failure = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] 'server' OR label CONTAINS[c] 'internet' OR label CONTAINS[c] 'connection' OR label CONTAINS[c] 'network'"
        )).firstMatch
        XCTAssertTrue(failure.waitForExistence(timeout: 30), "A failed login should show an error")
        snap("42-log-in-error")

        tapButton(containing: "Create an account")
        XCTAssertTrue(text(containing: "Create a free account").waitForExistence(timeout: 5))
        snap("43-sign-up")
        tap(app.navigationBars.buttons["Cancel"])

        tapButton(containing: "Skip for now")
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 5))
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Save your progress'")).firstMatch
            .waitForExistence(timeout: 5))
        snap("44-profile-account")
        tapButton(containing: "Save your progress")
        XCTAssertTrue(text(containing: "Create a free account").waitForExistence(timeout: 5))
    }

    /// The workout in progress on the Lock Screen and in the Dynamic Island.
    func testWorkoutLiveActivity() {
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestDemoHistory"]
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))

        tapButton(containing: "Start Workout")
        allowNotificationsIfAsked()
        let completeSet = app.buttons["Complete set 1"].firstMatch
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5))
        completeSet.tap()
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 5), "Completing a set starts the rest timer")

        // Dynamic Island: shown once the app is in the background.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        snap("80-dynamic-island")

        // Lock Screen.
        let lock = NSSelectorFromString("pressLockButton")
        if XCUIDevice.shared.responds(to: lock) {
            XCUIDevice.shared.perform(lock)
            Thread.sleep(forTimeInterval: 2)
            XCUIDevice.shared.press(.home)   // wake the screen without unlocking
            Thread.sleep(forTimeInterval: 2)
            snap("81-lock-screen")
            XCUIDevice.shared.press(.home)
        }
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
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

    func testCustomExercisesAndReminders() {
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestDemoHistory"]
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))

        // Reminders stay set after going back.
        app.buttons["Profile"].tap()
        tapButton(containing: "Reminders")
        let toggle = app.switches["Workout reminders"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        allowNotificationsIfAsked()
        tap(app.buttons["Tuesday"])
        snap("70-reminders-set")
        tap(app.navigationBars["Reminders"].buttons.element(boundBy: 0))
        let summary = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "4 days a week")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Profile shows the saved reminders")
        snap("71-profile-reminders")
        tapButton(containing: "Reminders")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1", "Reminders stay on after going back")
        XCTAssertTrue(app.buttons["Tuesday"].isSelected, "Picked days are kept")
        XCTAssertTrue(app.datePickers.firstMatch.exists, "Time picker still shows")
        snap("72-reminders-reopened")
        tap(app.navigationBars["Reminders"].buttons.element(boundBy: 0))

        // Create your own exercise in the library…
        app.buttons["Plans"].tap()
        XCTAssertTrue(app.navigationBars["Plans"].waitForExistence(timeout: 5))
        tapButton(containing: "Exercise library")
        tap(app.buttons["libraryCreateExercise"])
        let name = app.textFields["exerciseName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Landmine Press")
        tap(app.buttons["primary.shoulders"])
        snap("73-custom-exercise-form")
        tap(app.navigationBars["New Exercise"].buttons["Save"])
        let landmine = text(containing: "Landmine Press")
        XCTAssertTrue(landmine.waitForExistence(timeout: 5), "New exercise shows in the library")
        snap("74-library-custom")
        landmine.tap()
        tap(app.buttons["Edit Landmine Press"])
        XCTAssertTrue(app.navigationBars["Edit Exercise"].waitForExistence(timeout: 5))
        snap("75-edit-custom")
        tap(app.navigationBars["Edit Exercise"].buttons["Cancel"])

        // …or straight from the exercise picker in a workout.
        app.buttons["Home"].tap()
        tapButton(containing: "Start Workout")
        allowNotificationsIfAsked()
        tapButton(containing: "Add exercise")
        XCTAssertTrue(app.navigationBars["Add to Workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(containing: "Landmine Press").waitForExistence(timeout: 5), "Your own exercises show in the picker")
        tap(app.buttons["pickerCreateExercise"])
        let pickerName = app.textFields["exerciseName"]
        XCTAssertTrue(pickerName.waitForExistence(timeout: 5))
        pickerName.tap()
        pickerName.typeText("Cable Y Raise")
        tap(app.buttons["primary.shoulders"])
        tap(app.navigationBars["New Exercise"].buttons["Save"])
        let add = app.navigationBars["Add to Workout"].buttons["Add (1)"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "The new exercise is picked straight away")
        snap("76-picker-custom")
        add.tap()
        XCTAssertTrue(text(containing: "Cable Y Raise").waitForExistence(timeout: 5), "It's added to the workout")
        snap("77-workout-custom")
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
        var swipes = 0
        // Lazy lists only create rows near the screen, so scroll until the button shows up.
        if !button.waitForExistence(timeout: 5) {
            while !button.exists && swipes < 12 {
                app.swipeUp()
                swipes += 1
            }
        }
        XCTAssertTrue(button.exists, "No button containing '\(text)'", file: file, line: line)
        while !button.isHittable && swipes < 12 {
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
