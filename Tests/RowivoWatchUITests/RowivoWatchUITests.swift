import XCTest

@MainActor final class RowivoWatchUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testRecentTrainingShowsStartChoiceAndCanBeCancelled() {
        let app = launch("recent", german: true)
        let start = app.buttons["watch.start"]
        for _ in 0..<3 { if start.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(start.isEnabled); start.tap()
        XCTAssertTrue(app.staticTexts["Weitere Einheit starten?"].waitForExistence(timeout: 5))
        capture(app, "Watch recent training confirmation German")
        // watchOS exposes native alert actions as table buttons.
        app.buttons["Abbrechen"].firstMatch.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertTrue(start.isEnabled)
    }

    func testReadyWorkoutInGerman() {
        let app = launch("ready", german: true)
        XCTAssertTrue(app.staticTexts["watch.workout"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["watch.workout"].label, "Intervalle")
        XCTAssertTrue(app.buttons["watch.start"].isEnabled)
        capture(app, "Watch ready German")
    }
    func testActiveWorkoutAndMonitorValues() {
        let app = launch("active")
        XCTAssertTrue(app.staticTexts["watch.remaining"].waitForExistence(timeout: 5))
        capture(app, "Watch active English")
        for _ in 0..<3 { if app.buttons["watch.pause"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.buttons["watch.pause"].isEnabled)
        XCTAssertTrue(app.buttons["watch.finish"].exists)
        capture(app, "Watch controls English")
    }
    func testOfflineTimerKeepsCountingWithoutEnablingControls() {
        let app = launch("offline")
        let timer = app.staticTexts["watch.remaining"]
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        let before = timer.label
        let changed = NSPredicate { _, _ in timer.label != before }
        expectation(for: changed, evaluatedWith: nil)
        waitForExpectations(timeout: 4)
        for _ in 0..<4 { if app.buttons["watch.pause"].isHittable { break }; app.swipeUp() }
        XCTAssertFalse(app.buttons["watch.pause"].isEnabled)
        capture(app, "Offline timer continues")
    }
    func testOfflineSessionCannotBeControlled() {
        let app = launch("offline", german: true)
        XCTAssertTrue(app.staticTexts["watch.workout"].waitForExistence(timeout: 5))
        for _ in 0..<4 { if app.buttons["watch.pause"].isHittable { break }; app.swipeUp() }
        XCTAssertFalse(app.buttons["watch.pause"].isEnabled)
        XCTAssertFalse(app.buttons["watch.finish"].isEnabled)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["iPhone-Verbindung erforderlich"].exists)
        capture(app, "Watch offline German")
    }
    func testFirstLaunchGuidance() {
        let app = launch("empty", german: true)
        XCTAssertTrue(app.staticTexts["Richte Rowivo auf deinem iPhone ein"].waitForExistence(timeout: 5))
        capture(app, "Watch setup German")
    }
    func testFeedbackEffortButtonsDeleteCancellationAndBack() {
        let app = launch("paused", german: true)
        let finish = app.buttons["watch.finish"]
        for _ in 0..<5 { if finish.isHittable { break }; app.swipeUp() }
        finish.tap()
        let effort = app.buttons["watch.effort.4"]
        XCTAssertTrue(effort.waitForExistence(timeout: 5))
        for _ in 0..<5 { if effort.isHittable { break }; app.swipeUp() }
        if effort.frame.maxY > app.frame.maxY - 16 { app.swipeUp() }
        effort.tap()
        XCTAssertEqual(app.staticTexts["watch.effort.description"].label, "Anstrengend")
        for value in 1...5 { XCTAssertTrue(app.buttons["watch.effort.\(value)"].isHittable) }
        capture(app, "Watch feedback effort German")
        let discard = app.buttons["watch.discard"]
        for _ in 0..<8 { if discard.isHittable { break }; app.swipeUp() }
        discard.tap()
        XCTAssertTrue(app.tables.buttons["Aufzeichnung löschen"].waitForExistence(timeout: 5))
        app.buttons["AX_ActionContentControllerCancelButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["watch.save"].exists)
        app.buttons["watch.feedback.back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["watch.resume"].waitForExistence(timeout: 5))
    }
    func testPairedPhoneDiscardRecording() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ROWIVO_LIVE_PAIR"] == "1", "Requires an explicitly prepared, in-memory paired iPhone.")
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let start = app.buttons["watch.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        tapWhenConfirmed(start)
        XCTAssertTrue(app.staticTexts["watch.remaining"].waitForExistence(timeout: 15))
        let finish = app.buttons["watch.finish"]
        for _ in 0..<5 { if finish.isHittable { break }; app.swipeUp() }
        tapWhenConfirmed(finish)
        let discard = app.buttons["watch.discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 15))
        for _ in 0..<8 { if discard.isHittable { break }; app.swipeUp() }
        tapWhenConfirmed(discard)
        let confirm = app.tables.buttons["Delete recording"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        for _ in 0..<3 { if confirm.isHittable { break }; app.tables.firstMatch.swipeUp() }
        tapWhenConfirmed(confirm)
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Session saved"].exists)
    }
    /// Opt-in only: first launch the paired iPhone with --uitesting --seed-profile --enable-watch-connection.
    func testPairedPhoneSessionRoundTrip() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ROWIVO_LIVE_PAIR"] == "1", "Requires an explicitly prepared, in-memory paired iPhone.")
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let start = app.buttons["watch.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 30)
        capture(app, "Watch paired next workout")
        tapWhenConfirmed(start)
        XCTAssertTrue(app.staticTexts["watch.remaining"].waitForExistence(timeout: 15))
        let pause = app.buttons["watch.pause"]
        for _ in 0..<4 { if pause.isHittable { break }; app.swipeUp() }
        tapWhenConfirmed(pause)
        let resume = app.buttons["watch.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        tapWhenConfirmed(resume)
        XCTAssertTrue(pause.waitForExistence(timeout: 15))
        tapWhenConfirmed(app.buttons["watch.finish"])
        let save = app.buttons["watch.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        for _ in 0..<6 { if save.isHittable { break }; app.swipeUp() }
        tapWhenConfirmed(save)
        XCTAssertTrue(app.staticTexts["Session saved"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Session saved"].isHittable)
        capture(app, "Watch paired session saved")
    }
    private func tapWhenConfirmed(_ button: XCUIElement) {
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: button)
        waitForExpectations(timeout: 15)
        button.tap()
    }
    private func launch(_ mode: String, german: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--watch-preview", mode, "-AppleLanguages", german ? "(de)" : "(en)", "-AppleLocale", german ? "de_AT" : "en_US"]
        app.launch(); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
}
