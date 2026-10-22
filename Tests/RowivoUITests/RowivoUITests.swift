import XCTest

@MainActor final class RowivoUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testSavedSessionDeletionOnlyInEditorWithConfirmation() {
        let app = launch(seed: true, german: true)
        app.buttons["dashboard.workout"].tap()
        app.buttons["workout.manual"].tap()
        reveal(app.buttons["feedback.save"], in: app); app.buttons["feedback.save"].tap()
        let cardDelete = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "workout.delete-recording.")).firstMatch
        let edit = app.buttons["workout.edit-recording"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertFalse(cardDelete.exists)
        reveal(edit, in: app); edit.tap()
        XCTAssertTrue(app.textFields["recording.editor.name"].waitForExistence(timeout: 5))
        let delete = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recording.editor.delete-recording.")).firstMatch
        reveal(delete, in: app); delete.tap()
        let alert = app.alerts["Gespeicherte Einheit löschen?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        capture(app, "Delete saved session from editor German")
        alert.buttons["Abbrechen"].tap()
        XCTAssertTrue(delete.exists)
        delete.tap()
        app.alerts.buttons["recording.delete.confirm"].firstMatch.tap()
        XCTAssertTrue(app.buttons["workout.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["workout.start"].isEnabled)
        XCTAssertFalse(edit.exists)
    }

    func testPhoneStartFinishAndPDFShare() {
        let app = launch(seed: true, german: true)
        app.buttons["dashboard.workout"].tap()
        app.buttons["workout.start"].tap()
        XCTAssertTrue(app.buttons["workout.end"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["workout.end"].isHittable)
        capture(app, "Two progress rings German")
        app.buttons["workout.end"].tap()
        app.buttons["Teil-Einheit speichern"].tap()
        let save = app.buttons["feedback.save"]
        reveal(save, in: app); save.tap()
        let share = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "workout.share-pdf.")).firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 5)); reveal(share, in: app); share.tap()
        capture(app, "Workout PDF share German")
    }

    func testNativeCalendarEditorCanBeCancelled() {
        let app = launch(seed: true)
        app.buttons["dashboard.workout"].tap()
        let calendar = app.buttons["workout.calendar"]
        reveal(calendar, in: app); calendar.tap()
        XCTAssertTrue(app.buttons["cancel-button"].waitForExistence(timeout: 5))
        capture(app, "Native workout calendar")
        app.buttons["cancel-button"].tap()
        XCTAssertTrue(app.buttons["workout.start"].waitForExistence(timeout: 5))
    }

    func testProfileCanBeEditedCancelledAndReopened() {
        let app = launch(seed: true)
        app.buttons["settings.open"].tap()
        reveal(app.buttons["profile.edit"], in: app)
        app.buttons["profile.edit"].tap()
        let name = app.textFields["profile.editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Alex")
        replaceText(in: name, with: "Robin\n")
        app.buttons["profile.editor.cancel"].tap()
        app.buttons["profile.edit"].tap()
        XCTAssertEqual(name.value as? String, "Alex")
        replaceText(in: name, with: "Robin\n")
        app.buttons["profile.editor.goal"].tap(); app.buttons["Build endurance"].tap()
        app.buttons["profile.editor.experience"].tap(); app.buttons["Getting back into it"].tap()
        app.buttons["profile.editor.duration"].tap(); app.buttons["40 min"].tap()
        capture(app, "Profile editor English")
        app.buttons["profile.editor.save"].tap()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 5))
        app.buttons["profile.edit"].tap()
        XCTAssertEqual(name.value as? String, "Robin")
        XCTAssertTrue(app.buttons["profile.editor.goal"].label.contains("Build endurance"))
        XCTAssertTrue(app.buttons["profile.editor.experience"].label.contains("Getting back into it"))
        XCTAssertTrue(app.buttons["profile.editor.duration"].label.contains("40 min"))
        app.buttons["profile.editor.cancel"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Ready when you are, Robin."].exists)
    }

    func testRecentTrainingCanBeCancelledThenExplicitlyStartedInGerman() {
        let app = launch(seed: true, german: true)
        app.buttons["dashboard.workout"].tap(); app.buttons["workout.manual"].tap()
        reveal(app.buttons["feedback.save"], in: app); app.buttons["feedback.save"].tap()
        // Return to Today and open the next planned session.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeDown()
        let next = app.buttons["dashboard.workout"]
        XCTAssertTrue(next.waitForExistence(timeout: 5)); next.tap()
        XCTAssertTrue(app.buttons["workout.start"].isEnabled)
        app.buttons["workout.start"].tap()
        let alert = app.alerts["Weitere Einheit starten?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        capture(app, "Recent training confirmation German")
        alert.buttons["Abbrechen"].tap()
        XCTAssertTrue(app.buttons["workout.start"].exists)
        XCTAssertFalse(app.buttons["workout.pause"].exists)
        app.buttons["workout.start"].tap()
        alert.buttons["Trotzdem starten"].tap()
        XCTAssertTrue(app.buttons["workout.pause"].waitForExistence(timeout: 5))
        app.buttons["workout.pause"].tap()
        XCTAssertTrue(app.buttons["workout.pause"].label.contains("Weiter"))
    }

    func testCompletedSessionCanBeFullyEditedCancelledAndReopened() {
        let app = launch(seed: true)
        app.buttons["dashboard.workout"].tap(); app.buttons["workout.manual"].tap()
        reveal(app.buttons["feedback.save"], in: app); app.buttons["feedback.save"].tap()
        app.tabBars.buttons["Plan"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.workout.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let editButton = app.buttons["workout.edit-recording"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        for save in [false, true] {
            editButton.tap()
            let name = app.textFields["recording.editor.name"]
            XCTAssertTrue(name.waitForExistence(timeout: 5))
            XCTAssertNotEqual(name.value as? String, "Corrected row")
            name.tap(); name.typeText("Corrected row\n")
            app.buttons["recording.editor.kind"].tap()
            app.buttons["Recovery row"].tap()
            let minutes = app.textFields["recording.editor.minutes"]
            XCTAssertEqual(minutes.value as? String, "30")
            replaceText(in: minutes, with: XCUIKeyboardKey.delete.rawValue)
            XCTAssertFalse(app.buttons["recording.editor.save"].isEnabled)
            minutes.typeText("31")
            replaceText(in: app.textFields["recording.editor.seconds"], with: "30")
            app.buttons["recording.editor.keyboard-done"].tap()
            capture(app, "Full session editor English")
            let effort = app.buttons["recording.editor.effort.4"]
            reveal(effort, in: app); effort.tap()
            let discomfort = app.switches["recording.editor.discomfort"]
            XCTAssertEqual(discomfort.value as? String, "0")
            reveal(discomfort, in: app)
            // The native switch's accessibility frame also includes its non-interactive label.
            discomfort.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            XCTAssertEqual(discomfort.value as? String, "1")
            let note = app.textViews["recording.editor.note"]
            reveal(note, in: app); note.tap(); note.typeText("Fixed my typo.")
            app.buttons["recording.editor.keyboard-done"].tap()
            capture(app, "Full session feedback English")
            app.buttons[save ? "recording.editor.save" : "recording.editor.cancel"].tap()
            XCTAssertTrue(editButton.waitForExistence(timeout: 5))
            if !save {
                XCTAssertFalse(app.staticTexts["Corrected row"].exists)
                XCTAssertFalse(app.staticTexts["Fixed my typo."].exists)
            }
        }
        XCTAssertTrue(app.staticTexts["Corrected row"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["31 min 30 sec"].exists)
        XCTAssertTrue(app.staticTexts["Fixed my typo."].exists)
        capture(app, "Corrected completed session English")
        editButton.tap()
        XCTAssertEqual(app.textFields["recording.editor.name"].value as? String, "Corrected row")
        XCTAssertEqual(app.textFields["recording.editor.minutes"].value as? String, "31")
        XCTAssertEqual(app.textFields["recording.editor.seconds"].value as? String, "30")
        XCTAssertTrue(app.buttons["recording.editor.kind"].label.contains("Recovery row"))
        reveal(app.buttons["recording.editor.effort.4"], in: app)
        XCTAssertTrue(app.buttons["recording.editor.effort.4"].isSelected)
        XCTAssertEqual(app.switches["recording.editor.discomfort"].value as? String, "1")
        reveal(app.textViews["recording.editor.note"], in: app)
        XCTAssertEqual(app.textViews["recording.editor.note"].value as? String, "Fixed my typo.")
        app.buttons["recording.editor.cancel"].tap()
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Corrected row"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "31 min 30 sec")).firstMatch.exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.edit-recording.")).count, 1)
    }

    func testSavedSessionEditorInGermanFromHistoryAndToday() {
        let app = launch(seed: true, german: true)
        app.buttons["dashboard.workout"].tap(); app.buttons["workout.manual"].tap()
        reveal(app.buttons["feedback.save"], in: app); app.buttons["feedback.save"].tap()
        app.tabBars.buttons["Fortschritt"].tap()
        let editButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.edit-recording.")).firstMatch
        reveal(editButton, in: app)
        XCTAssertTrue(editButton.label.contains("Einheit bearbeiten")); editButton.tap()
        XCTAssertTrue(app.navigationBars["Einheit bearbeiten"].waitForExistence(timeout: 5))
        let name = app.textFields["recording.editor.name"]
        name.tap(); name.typeText("Meine Korrektur\n")
        replaceText(in: app.textFields["recording.editor.minutes"], with: "27")
        app.buttons["recording.editor.keyboard-done"].tap()
        capture(app, "Full session editor German")
        reveal(app.buttons["recording.editor.effort.3"], in: app)
        app.buttons["recording.editor.effort.3"].tap()
        let note = app.textViews["recording.editor.note"]
        reveal(note, in: app); note.tap(); note.typeText("Dauer korrigiert")
        app.buttons["recording.editor.keyboard-done"].tap()
        capture(app, "Full session feedback German")
        app.buttons["recording.editor.save"].tap()
        XCTAssertTrue(app.staticTexts["Meine Korrektur"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.edit-recording.")).count, 1)
        app.tabBars.buttons["Heute"].tap()
        // Return from Today's preserved workout detail to its overview.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let todayEdit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.edit-recording.")).firstMatch
        reveal(todayEdit, in: app); todayEdit.tap()
        XCTAssertEqual(app.textFields["recording.editor.name"].value as? String, "Meine Korrektur")
        XCTAssertEqual(app.textFields["recording.editor.minutes"].value as? String, "27")
        app.buttons["recording.editor.cancel"].tap()
    }

    func testPlanAndTodayShowActualValuesAndEditTheSameRecording() {
        let app = launch(seed: true)
        app.buttons["dashboard.workout"].tap()
        app.buttons["workout.manual"].tap()
        let minutes = app.steppers["feedback.minutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        for _ in 0..<3 { minutes.buttons["feedback.minutes-Decrement"].tap() }
        XCTAssertEqual(app.staticTexts["feedback.duration"].label, "27 min")
        reveal(app.buttons["feedback.save"], in: app); app.buttons["feedback.save"].tap()
        XCTAssertTrue(app.staticTexts["Actual duration"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["27 min"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "30 min")).firstMatch.exists)
        capture(app, "Plan versus actual English")
        app.tabBars.buttons["Plan"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.workout.")).firstMatch
        XCTAssertTrue(row.label.contains("Planned: 30 min"), row.label)
        XCTAssertTrue(row.label.contains("Last recorded: 27 min"), row.label)
        row.tap()
        let edit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "workout.edit-recording.")).firstMatch
        reveal(edit, in: app); edit.tap()
        let picker = app.datePickers["recording.editor.date"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons.firstMatch.tap()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        if Calendar.current.component(.month, from: yesterday) != Calendar.current.component(.month, from: Date()) {
            app.buttons.matching(NSPredicate(format: "label IN %@", ["Previous Month", "Previous month"])).firstMatch.tap()
        }
        let day = DateFormatter(); day.locale = Locale(identifier: "en_US"); day.dateFormat = "EEEE, MMMM d"
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", day.string(from: yesterday))).firstMatch.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.2)).tap()
        app.buttons["recording.editor.save"].tap()
        day.dateStyle = .medium; day.timeStyle = .none
        let expected = day.string(from: yesterday)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "workout.date.")).firstMatch.label.contains(expected))
        app.tabBars.buttons["Today"].tap()
        // Today retains its own navigation stack from the initial manual log.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let todayEdit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.edit-recording.")).firstMatch
        reveal(todayEdit, in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.date.")).firstMatch.label.contains(expected))
        capture(app, "Today planned and recorded English")
        todayEdit.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        app.buttons["recording.editor.save"].tap()
        app.tabBars.buttons["Progress"].tap()
        let historyDate = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.date.")).firstMatch
        XCTAssertTrue(historyDate.waitForExistence(timeout: 5))
        XCTAssertTrue(historyDate.label.contains(expected))
        XCTAssertTrue(app.staticTexts["27 min"].exists)
    }

    func testDeleteProfileConfirmationAndFreshOnboardingInGerman() {
        let app = launch(seed: true, german: true)
        capture(app, "Today logo spacing German")
        app.buttons["dashboard.workout"].tap()
        app.buttons["workout.manual"].tap()
        reveal(app.buttons["feedback.save"], in: app); app.buttons["feedback.save"].tap()
        XCTAssertTrue(app.staticTexts["Tatsächliche Dauer"].waitForExistence(timeout: 5))
        capture(app, "Plan versus actual German")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings.open"].tap()
        let delete = app.buttons["settings.delete"]
        reveal(delete, in: app); delete.tap()
        XCTAssertTrue(app.alerts["Alle lokalen Daten löschen?"].waitForExistence(timeout: 5))
        capture(app, "Delete local data confirmation German")
        app.alerts.buttons["Abbrechen"].tap()
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["onboarding.start"].exists)
        delete.tap()
        app.alerts.buttons.matching(identifier: "settings.confirm-delete").firstMatch.tap()
        let start = app.buttons["onboarding.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        capture(app, "Fresh onboarding after deletion German")
        start.tap()
        let name = app.textFields["profile.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertNotEqual(name.value as? String, "Alex")
        name.tap(); name.typeText("Neustart\n")
        reveal(app.buttons["profile.create"], in: app); app.buttons["profile.create"].tap()
        XCTAssertTrue(app.buttons["plan.first-add"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Fortschritt"].tap()
        XCTAssertTrue(app.staticTexts["Noch keine Aufzeichnungen"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.edit-recording.")).count, 0)
        app.tabBars.buttons["Heute"].tap()
        app.buttons["settings.open"].tap()
        app.buttons["storage.open"].tap()
        XCTAssertTrue(app.staticTexts["storage.off"].waitForExistence(timeout: 5))
    }

    func testManualWorkoutDateSelectionCorrectionAndHistory() {
        let app = launch(seed: true)
        app.buttons["dashboard.workout"].tap()
        app.buttons["workout.manual"].tap()
        let picker = app.datePickers["feedback.date"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        capture(app, "Manual workout date English")
        picker.buttons.firstMatch.tap()
        let target = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        if Calendar.current.component(.month, from: target) != Calendar.current.component(.month, from: Date()) {
            app.buttons.matching(NSPredicate(format: "label IN %@", ["Previous Month", "Previous month"])).firstMatch.tap()
        }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", formatter.string(from: target))).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 3), app.debugDescription)
        day.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.2)).tap()
        reveal(app.buttons["feedback.save"], in: app)
        app.buttons["feedback.save"].tap()
        app.tabBars.buttons["Progress"].tap()
        let historyDate = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.date.")).firstMatch
        XCTAssertTrue(historyDate.waitForExistence(timeout: 5))
        formatter.dateStyle = .medium; formatter.timeStyle = .none
        XCTAssertTrue(historyDate.label.contains(formatter.string(from: target)), historyDate.label)
        capture(app, "Backdated history English")
        let edit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.edit-recording.")).firstMatch
        let corrected = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        for save in [false, true] {
            reveal(edit, in: app); edit.tap()
            let datePicker = app.datePickers["recording.editor.date"]
            XCTAssertTrue(datePicker.waitForExistence(timeout: 5))
            datePicker.buttons.firstMatch.tap()
            if Calendar.current.component(.month, from: corrected) != Calendar.current.component(.month, from: target) {
                app.buttons.matching(NSPredicate(format: "label IN %@", ["Next Month", "Next month"])).firstMatch.tap()
            }
            let dayFormatter = DateFormatter(); dayFormatter.locale = Locale(identifier: "en_US"); dayFormatter.dateFormat = "EEEE, MMMM d"
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", dayFormatter.string(from: corrected))).firstMatch.tap()
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.2)).tap()
            app.buttons[save ? "recording.editor.save" : "recording.editor.cancel"].tap()
            XCTAssertTrue(historyDate.waitForExistence(timeout: 5))
            XCTAssertTrue(historyDate.label.contains(formatter.string(from: save ? corrected : target)), historyDate.label)
        }
        capture(app, "Corrected existing workout English")
        let german = launch(seed: true, german: true)
        german.buttons["dashboard.workout"].tap()
        german.buttons["workout.manual"].tap()
        XCTAssertTrue(german.datePickers["feedback.date"].waitForExistence(timeout: 5))
        XCTAssertTrue(german.staticTexts["Trainingsdatum"].exists)
        capture(german, "Manual workout date German")
        reveal(german.buttons["feedback.save"], in: german)
        german.buttons["feedback.save"].tap()
        german.tabBars.buttons["Fortschritt"].tap()
        let germanEdit = german.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.edit-recording.")).firstMatch
        reveal(germanEdit, in: german); germanEdit.tap()
        XCTAssertTrue(german.datePickers["recording.editor.date"].waitForExistence(timeout: 5))
        capture(german, "Edit existing workout date German")
        german.buttons["recording.editor.cancel"].tap()
    }

    func testPlanRowOpensWithOneTapIncludingEmptySpace() {
        let app = launch(seed: true)
        app.tabBars.buttons["Plan"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.workout.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        capture(app, "Plan English")
        // The first point lands in the empty space between the label and chevron.
        for point in [CGVector(dx: 0.80, dy: 0.5), CGVector(dx: 0.50, dy: 0.95),
                      CGVector(dx: 0.05, dy: 0.5), CGVector(dx: 0.96, dy: 0.5)] {
            row.coordinate(withNormalizedOffset: point).tap()
            guard app.staticTexts["workout.title"].waitForExistence(timeout: 3) else {
                XCTFail("A single tap at \(point) did not open the workout")
                return
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(row.waitForExistence(timeout: 3))
        }
    }

    func testGermanPlanRowsAndScrolling() {
        let app = launch(seed: true, german: true)
        app.tabBars.buttons["Plan"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.workout."))
        let thirdRow = rows.element(boundBy: 2)
        XCTAssertTrue(thirdRow.waitForExistence(timeout: 5))
        capture(app, "Plan German")
        thirdRow.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.5)).tap()
        let title = app.staticTexts["workout.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "Technik üben")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Locker")).count, 1)
        capture(app, "Workout German")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let intervals = rows.matching(NSPredicate(format: "label CONTAINS %@", "Intervalle")).firstMatch
        reveal(intervals, in: app)
        capture(app, "Plan scrolled German")
        intervals.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.5)).tap()
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "Intervalle")
    }

    func testOnboardingManualSessionAndHistory() {
        let app = launch()
        capture(app, "Welcome English")
        app.buttons["onboarding.start"].tap()
        let name = app.textFields["profile.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Alex\n")
        reveal(app.buttons["profile.create"], in: app)
        app.buttons["profile.create"].tap()
        XCTAssertTrue(app.buttons["plan.first-add"].waitForExistence(timeout: 5))
        capture(app, "Empty plan English")
        app.buttons["plan.first-add"].tap()
        let workoutName = app.textFields["editor.name"]
        XCTAssertTrue(workoutName.waitForExistence(timeout: 5))
        workoutName.tap(); workoutName.typeText("Morning row\n")
        app.buttons["editor.step.1"].tap()
        let seconds = app.textFields["step.seconds"]
        XCTAssertTrue(seconds.waitForExistence(timeout: 5))
        replaceText(in: seconds, with: "30")
        XCTAssertTrue(app.buttons["step.save"].isEnabled)
        app.buttons["step.save"].tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
        capture(app, "Workout editor English")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.workout.")).firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["Today"].tap()
        let workout = app.buttons["dashboard.workout"]
        XCTAssertTrue(workout.waitForExistence(timeout: 5))
        capture(app, "Today English")
        workout.tap()
        reveal(app.buttons["workout.manual"], in: app)
        app.buttons["workout.manual"].tap()
        XCTAssertTrue(app.staticTexts["feedback.duration"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["feedback.duration"].label, "30 min 30 sec")
        reveal(app.buttons["feedback.save"], in: app)
        app.buttons["feedback.save"].tap()
        XCTAssertTrue(app.otherElements["workout.saved"].waitForExistence(timeout: 5) || app.staticTexts["Session recorded"].exists)
        XCTAssertFalse(app.buttons["workout.start"].exists)
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Logged workouts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Morning row"].exists)
        capture(app, "Progress English")
    }

    func testTimerPauseAndResumeAndDiscard() {
        let app = launch(seed: true)
        app.buttons["dashboard.workout"].tap()
        app.buttons["workout.start"].tap()
        let pause = app.buttons["workout.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        XCTAssertTrue(pause.label.contains("Continue"))
        capture(app, "Paused workout English")
        app.buttons["Back to app"].tap()
        XCTAssertTrue(app.buttons["Resume session"].waitForExistence(timeout: 5))
        app.buttons["Resume session"].tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        XCTAssertTrue(pause.label.contains("Continue"))
        app.buttons["workout.end"].tap()
        app.buttons["Discard session"].tap()
        XCTAssertTrue(app.buttons["workout.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["workout.start"].isEnabled)
    }

    func testGermanManualEditorAndSettings() {
        let app = launch(seed: true, german: true)
        XCTAssertTrue(app.staticTexts["Bereit, Alex?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Technik üben"].exists)
        capture(app, "Today German")
        XCTAssertEqual(app.tabBars.buttons.count, 3)
        XCTAssertFalse(app.tabBars.buttons["Coach"].exists)
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.buttons["storage.open"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.secureTextFields["settings.api-key"].exists)
        XCTAssertFalse(app.switches["settings.consent"].exists)
        capture(app, "Settings without AI German")
        app.buttons["Fertig"].tap()
        app.tabBars.buttons["Plan"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.workout.")).firstMatch
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
        app.buttons["workout.edit"].tap()
        let name = app.textFields["editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Mein Morgenrudern\n")
        app.buttons["editor.step.1"].tap()
        let minutes = app.textFields["step.minutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        replaceText(in: minutes, with: "7")
        let seconds = app.textFields["step.seconds"]
        replaceText(in: seconds, with: "30")
        XCTAssertEqual(minutes.value as? String, "7")
        XCTAssertEqual(seconds.value as? String, "30")
        XCTAssertTrue(app.buttons["step.save"].isEnabled)
        capture(app, "Step editor German")
        app.buttons["step.save"].tap()
        XCTAssertTrue(app.buttons["editor.step.1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["editor.step.1"].label.contains("07:30"))
        reveal(app.buttons["editor.intervals"], in: app)
        app.buttons["editor.intervals"].tap()
        XCTAssertTrue(app.buttons["intervals.insert"].waitForExistence(timeout: 5))
        capture(app, "Interval editor German")
        app.buttons["intervals.insert"].tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
        capture(app, "Workout editor German")
        app.buttons["editor.save"].tap()
        let title = app.staticTexts["workout.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Mein Morgenrudern")
        XCTAssertTrue(app.staticTexts["07:30"].exists)
        capture(app, "Custom workout German")
        app.buttons["workout.edit"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "Nicht speichern\n")
        app.buttons["Abbrechen"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Mein Morgenrudern")
        app.buttons["workout.options"].tap()
        app.buttons["Einheit duplizieren"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Kopie von Mein Morgenrudern")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let copy = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "plan.workout.", "Kopie von Mein Morgenrudern")).firstMatch
        reveal(copy, in: app)
        XCTAssertTrue(copy.exists)
    }

    func testRowerConnectionSetupAndSimulatorStateInGerman() {
        let app = launch(seed: true, german: true)
        let connection = app.buttons["pm5.open"]
        reveal(connection, in: app); connection.tap()
        XCTAssertTrue(app.buttons["pm5.search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["pm5.simulator"].exists)
        XCTAssertTrue(app.staticTexts["Concept2 PM5 und FTMS-Rudergeräte"].exists)
        app.buttons["pm5.search"].tap()
        XCTAssertEqual(app.staticTexts["pm5.status"].label, "Bluetooth nicht verfügbar")
        XCTAssertFalse(app.buttons["pm5.disconnect"].exists)
        capture(app, "Rower connection German")
        app.buttons["Fertig"].tap()
        app.swipeDown()
        app.buttons["dashboard.workout"].tap()
        app.buttons["workout.start"].tap()
        XCTAssertTrue(app.buttons["pm5.open"].waitForExistence(timeout: 5))
        app.buttons["pm5.open"].tap()
        XCTAssertTrue(app.buttons["pm5.search"].waitForExistence(timeout: 5))
    }

    func testStorageStartsPrivateAndExportsThroughFiles() {
        let app = launch(seed: true, german: true)
        app.buttons["settings.open"].tap()
        app.buttons["storage.open"].tap()
        XCTAssertTrue(app.staticTexts["Deine Daten. Deine Wahl."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["storage.off"].exists)
        XCTAssertFalse(app.switches["storage.auto"].exists)
        capture(app, "Storage German")
        app.buttons["storage.folder"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Abbrechen"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8)); cancel.tap()
        XCTAssertTrue(app.buttons["storage.folder"].waitForExistence(timeout: 5))
        reveal(app.buttons["storage.export"], in: app)
        app.buttons["storage.export"].tap()
        let save = app.buttons.matching(NSPredicate(format: "label IN %@", ["Save", "Sichern"])).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        capture(app, "CSV file export picker")
        save.tap()
        XCTAssertTrue(app.buttons["storage.export"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Dateien an deinen Anbieter übergeben. Dein Anbieter übernimmt das Hochladen."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["storage.save"].exists)
        reveal(app.buttons["storage.restore"], in: app)
        app.buttons["storage.restore"].tap()
        let backup = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "training.rowivo,")).firstMatch
        XCTAssertTrue(backup.waitForExistence(timeout: 8)); backup.tap()
        XCTAssertTrue(app.buttons["storage.confirm-restore"].waitForExistence(timeout: 8))
        capture(app, "Restore preview German")
        app.buttons["storage.confirm-restore"].tap()
        XCTAssertTrue(app.staticTexts["Training wiederhergestellt. Cloud-Kopien sind ausgeschaltet."].waitForExistence(timeout: 8))
    }

    func testRestoreAvailableOnANewInstallation() {
        let app = launch()
        app.buttons["onboarding.restore"].tap()
        XCTAssertTrue(app.buttons["storage.restore"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["storage.export"].exists)
        app.buttons["storage.restore"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Abbrechen"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8)); cancel.tap()
        XCTAssertTrue(app.buttons["storage.restore"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["storage.confirm-restore"].exists)
    }

    private func launch(seed: Bool = false, german: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", german ? "(de)" : "(en)", "-AppleLocale", german ? "de_AT" : "en_US"]
        if seed { app.launchArguments.append("--seed-profile") }
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func replaceText(in field: XCUIElement, with text: String) {
        field.doubleTap()
        let app = XCUIApplication()
        let predicate = NSPredicate(format: "label IN %@", ["Select All", "Alles auswählen"])
        let menuItem = app.menuItems.matching(predicate).firstMatch
        let button = app.buttons.matching(predicate).firstMatch
        if menuItem.exists { menuItem.tap() }
        else if button.exists { button.tap() }
        field.typeText(text)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
