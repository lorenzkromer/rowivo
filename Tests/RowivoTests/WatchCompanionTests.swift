import XCTest
import SwiftData
import PDFKit
import RowivoCore
@testable import Rowivo

@MainActor final class WatchCompanionTests: XCTestCase {
    private func makeStore() throws -> RowivoStore {
        try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }
    func testWatchStartedSessionCanBePausedAndSavedOnPhone() throws {
        let store = try makeStore(); store.createProfile(.init(name: "Alex"), useTemplate: true)
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertEqual(store.performWatchCommand(.init(action: .start, snapshot: store.watchSnapshot())), .ok)
        XCTAssertTrue(store.showingWorkout)
        store.update { $0.clock = WorkoutClock(workoutID: workout.id, now: Date().addingTimeInterval(-90)) }
        store.prepareReflection()
        XCTAssertTrue(store.complete(workout, seconds: 90, effort: 3, discomfort: false, note: "Saved on phone", manual: false))
        XCTAssertEqual(store.state.completions.count, 1); XCTAssertNil(store.state.clock)
        XCTAssertEqual(store.watchSnapshot().lastSavedWorkoutID, workout.id)
        XCTAssertNotNil(store.watchSnapshot().lastSavedAt)
    }
    func testAutoPauseResumesButReflectionAndManualPauseRemainStopped() throws {
        let store = try makeStore(); store.createProfile(.init(name: "Alex"), useTemplate: true)
        var preferences = store.workoutPreferences; preferences.automaticPause = true
        store.setWorkoutPreferences(preferences)
        store.start(try XCTUnwrap(store.nextWorkout))
        let device = RowerDevice(id: UUID(), name: "Test PM5", signal: -50)
        let start = Date()
        for second in 0...6 {
            store.receiveRower(RowerSnapshot(date: start.addingTimeInterval(Double(second)), elapsed: Double(second), distance: 0, watts: 0), device: device)
        }
        XCTAssertNil(store.state.clock?.resumedAt); XCTAssertEqual(store.state.automaticallyPaused, true)
        for second in 7...9 {
            store.receiveRower(RowerSnapshot(date: start.addingTimeInterval(Double(second)), elapsed: Double(second), distance: Double(second), watts: 20), device: device)
        }
        XCTAssertNotNil(store.state.clock?.resumedAt)
        store.prepareReflection()
        for second in 10...20 {
            store.receiveRower(RowerSnapshot(date: start.addingTimeInterval(Double(second)), elapsed: Double(second), distance: Double(second), watts: 20), device: device)
        }
        XCTAssertNil(store.state.clock?.resumedAt); XCTAssertEqual(store.state.automaticallyPaused, false)
    }
    func testPDFContainsActualPlannedValuesAndPaginatesAllNotes() throws {
        let workout = Workout(kind: .intervals, segments: [.init(kind: .work, seconds: 600)])
        let note = String(repeating: "Zeile mit Umlauten: kräftig rudern. 🛶\n", count: 300) + "ENDOFNOTES"
        let log = WorkoutCompletion(workout: workout, durationSeconds: 450, effort: 3, discomfort: false, note: note, manuallyRecorded: true)
        let url = try WorkoutPDF.create(log, planned: workout)
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(pdf.pageCount, 1)
        let text = try XCTUnwrap(pdf.string)
        let attachment = XCTAttachment(data: try Data(contentsOf: url), uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "Paginated workout PDF"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertTrue(text.contains("ENDOFNOTES"), String(text.suffix(250)))
        XCTAssertTrue(text.contains("7") && text.contains("30"), String(text.prefix(500)))
        XCTAssertTrue(text.contains("Rowivo")); XCTAssertTrue(text.contains("10"))
    }
    func testWatchStartPauseResumeAndSaveUsesTheExistingRecording() throws {
        let store = try makeStore(); store.createProfile(.init(name: "Alex"), useTemplate: true)
        let workout = try XCTUnwrap(store.nextWorkout)
        let initial = store.watchSnapshot()
        XCTAssertEqual(store.performWatchCommand(.init(action: .start, snapshot: initial)), .ok)
        XCTAssertNotEqual(store.watchSnapshot().controlToken, initial.controlToken)
        XCTAssertEqual(store.performWatchCommand(.init(action: .start, snapshot: initial)), .stale)
        XCTAssertEqual(store.state.clock?.workoutID, workout.id)
        let started = store.watchSnapshot()
        XCTAssertEqual(store.performWatchCommand(.init(action: .pause, snapshot: started)), .ok)
        let paused = store.watchSnapshot()
        XCTAssertNil(store.state.clock?.resumedAt)
        XCTAssertEqual(store.performWatchCommand(.init(action: .pause, snapshot: started)), .stale)
        XCTAssertEqual(store.performWatchCommand(.init(action: .resume, snapshot: paused)), .ok)
        XCTAssertNotNil(store.state.clock?.resumedAt)
        store.update { $0.clock = WorkoutClock(workoutID: workout.id, now: Date().addingTimeInterval(-155)) }
        XCTAssertEqual(store.performWatchCommand(.init(action: .pause, snapshot: store.watchSnapshot())), .ok)
        let save = WatchCommand(action: .save, snapshot: store.watchSnapshot(), effort: 4, discomfort: true, note: "From my wrist")
        XCTAssertEqual(store.performWatchCommand(save), .ok)
        XCTAssertEqual(store.performWatchCommand(save), .stale)
        XCTAssertNil(store.state.clock); XCTAssertFalse(store.showingWorkout)
        let log = try XCTUnwrap(store.state.completions.first)
        XCTAssertEqual(store.state.completions.count, 1)
        XCTAssertEqual(log.workoutID, workout.id); XCTAssertEqual(log.durationSeconds, 155)
        XCTAssertEqual(log.effort, 4); XCTAssertTrue(log.discomfort); XCTAssertEqual(log.note, "From my wrist")
        XCTAssertFalse(log.manuallyRecorded); XCTAssertFalse(log.finishedPlan)
        let reopened = try RowivoStore(container: store.container)
        XCTAssertEqual(reopened.state.completions, [log])
        XCTAssertEqual(reopened.watchSnapshot().availability, .checkIn)
    }
    func testDelayedWrongWorkoutAndInvalidFeedbackDoNotMutateTraining() throws {
        let store = try makeStore(); store.createProfile(.init(name: "Alex"), useTemplate: true)
        let snapshot = store.watchSnapshot()
        var delayed = WatchCommand(action: .start, snapshot: snapshot, issuedAt: Date().addingTimeInterval(-31))
        XCTAssertEqual(store.performWatchCommand(delayed), .stale)
        delayed.issuedAt = Date(); delayed.workoutID = UUID()
        XCTAssertEqual(store.performWatchCommand(delayed), .unavailable)
        delayed.version = 2
        XCTAssertEqual(store.performWatchCommand(delayed), .invalid)
        XCTAssertNil(store.state.clock)
        XCTAssertEqual(store.performWatchCommand(.init(action: .start, snapshot: snapshot)), .ok)
        XCTAssertEqual(store.performWatchCommand(.init(action: .save, snapshot: store.watchSnapshot(), effort: 2, discomfort: false)), .unavailable)
        XCTAssertEqual(store.performWatchCommand(.init(action: .pause, snapshot: store.watchSnapshot())), .ok)
        let paused = store.watchSnapshot()
        for effort in [0, 6] {
            XCTAssertEqual(store.performWatchCommand(.init(action: .save, snapshot: paused, effort: effort, discomfort: false)), .invalid)
        }
        XCTAssertEqual(store.performWatchCommand(.init(action: .save, snapshot: paused, effort: 2, discomfort: false, note: String(repeating: "a", count: 2001))), .invalid)
        XCTAssertEqual(store.watchSnapshot().controlToken, paused.controlToken)
        XCTAssertTrue(store.state.completions.isEmpty)
    }
    func testPhoneChangesAndRelaunchInvalidateOldCommandsButTelemetryDoesNot() throws {
        let store = try makeStore(); store.createProfile(.init(name: "Alex"), useTemplate: true)
        let original = store.watchSnapshot()
        store.addBlock()
        XCTAssertEqual(store.performWatchCommand(.init(action: .start, snapshot: original)), .stale)
        let current = store.watchSnapshot()
        store.update { $0.currentPM5Recording = .init(deviceID: UUID(), deviceName: "Test PM5") }
        XCTAssertEqual(store.watchSnapshot().controlToken, current.controlToken)
        let reopened = try RowivoStore(container: store.container)
        XCTAssertEqual(reopened.performWatchCommand(.init(action: .start, snapshot: current)), .stale)
        XCTAssertEqual(reopened.performWatchCommand(.init(action: .refresh)), .ok)
    }
    func testResetPublishesEmptyStateAndRejectsOldWatchCommands() async throws {
        let store = try makeStore(); store.createProfile(.init(name: "Alex"), useTemplate: true)
        let original = store.watchSnapshot()
        var published: [WatchSnapshot] = []
        store.companionDidChange = { published.append(store.watchSnapshot()) }
        let deleted = await store.deleteAllData()
        XCTAssertTrue(deleted)
        XCTAssertEqual(published.last?.availability, .noProfile)
        XCTAssertNil(published.last?.workout); XCTAssertNil(published.last?.clock); XCTAssertNil(published.last?.metrics)
        XCTAssertEqual(store.performWatchCommand(.init(action: .start, snapshot: original)), .stale)
    }
    func testRecentTrainingNeedsExplicitWatchConfirmationAndCheckInStillApplies() throws {
        let store = try makeStore(); store.createProfile(.init(name: "Alex"), useTemplate: true)
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "", manual: true))
        XCTAssertEqual(store.watchSnapshot().availability, .restDay)
        XCTAssertEqual(store.performWatchCommand(.init(action: .start, snapshot: store.watchSnapshot())), .unavailable)
        let confirmed = WatchCommand(action: .start, snapshot: store.watchSnapshot(), acknowledgingRecentTraining: true)
        XCTAssertEqual(store.performWatchCommand(confirmed), .ok)
        XCTAssertEqual(store.performWatchCommand(confirmed), .stale)
        XCTAssertEqual(store.performWatchCommand(.init(action: .pause, snapshot: store.watchSnapshot())), .ok)
        XCTAssertEqual(store.performWatchCommand(.init(action: .save, snapshot: store.watchSnapshot(), effort: 2, discomfort: false)), .ok)
        store.update { $0.completions[$0.completions.count - 1].discomfort = true }
        XCTAssertEqual(store.watchSnapshot().availability, .checkIn)
        XCTAssertEqual(store.performWatchCommand(.init(action: .start, snapshot: store.watchSnapshot(), acknowledgingRecentTraining: true)), .unavailable)
    }
    func testWatchCompletionRetainsPM5Samples() throws {
        let store = try makeStore(); store.createProfile(.init(name: "Alex"), useTemplate: true)
        let workout = try XCTUnwrap(store.nextWorkout)
        store.start(workout)
        let start = Date().addingTimeInterval(-30)
        store.update { $0.clock = WorkoutClock(workoutID: workout.id, now: start) }
        let device = RowerDevice(id: UUID(), name: "Test PM5", signal: -40)
        store.receiveRower(.init(date: start, general: .init(elapsed: 0, distance: 0)), device: device)
        store.receiveRower(.init(date: start.addingTimeInterval(1), general: .init(elapsed: 1, distance: 4)), device: device)
        XCTAssertEqual(store.performWatchCommand(.init(action: .pause, snapshot: store.watchSnapshot())), .ok)
        let recording = store.rowerRecording
        XCTAssertEqual(store.performWatchCommand(.init(action: .save, snapshot: store.watchSnapshot(), effort: 2, discomfort: false)), .ok)
        XCTAssertEqual(store.state.completions.first?.pm5, recording)
    }
    func testWatchDiscardOnlyRemovesThePausedRecording() throws {
        let store = try makeStore(); store.createProfile(.init(name: "Alex"), useTemplate: true)
        let workout = try XCTUnwrap(store.nextWorkout)
        let plan = store.state.plan
        let history = store.state.completions
        store.start(workout)
        let running = store.watchSnapshot()
        XCTAssertEqual(store.performWatchCommand(.init(action: .discard, snapshot: running)), .unavailable)
        store.receiveRower(.init(date: Date(), general: .init(elapsed: 0, distance: 0)),
                         device: .init(id: UUID(), name: "Test PM5", signal: -40))
        XCTAssertEqual(store.performWatchCommand(.init(action: .pause, snapshot: store.watchSnapshot())), .ok)
        XCTAssertNotNil(store.state.currentPM5Recording)
        let paused = store.watchSnapshot()
        XCTAssertEqual(store.performWatchCommand(.init(action: .discard, snapshot: running)), .stale)
        XCTAssertEqual(store.performWatchCommand(.init(action: .discard, snapshot: paused)), .ok)
        XCTAssertNil(store.state.clock); XCTAssertNil(store.state.currentPM5Recording)
        XCTAssertNil(store.rowerRecording); XCTAssertFalse(store.showingWorkout)
        XCTAssertEqual(store.state.plan, plan); XCTAssertEqual(store.state.completions, history)
        XCTAssertEqual(store.nextWorkout?.id, workout.id)
        XCTAssertEqual(store.performWatchCommand(.init(action: .discard, snapshot: paused)), .stale)
        let reopened = try RowivoStore(container: store.container)
        XCTAssertNil(reopened.state.clock); XCTAssertNil(reopened.state.currentPM5Recording)
        XCTAssertEqual(reopened.state.plan, plan)
    }
}
