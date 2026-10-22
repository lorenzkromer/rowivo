import XCTest
import Security
import SwiftData
import RowivoCore
@testable import Rowivo

@MainActor final class RowivoTests: XCTestCase {
    func testJourneyCreditsOnlySavedMetersAndSurvivesBackupWithoutDuplicateCredits() async throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        let device = RowerDevice(id: UUID(), name: "Journey fixture", signal: -40)
        store.start(workout)
        let start = Date()
        for second in 0...100 {
            store.receiveRower(RowerSnapshot(date: start.addingTimeInterval(Double(second)), elapsed: Double(second), distance: 200 + Double(second) * 5), device: device)
        }
        XCTAssertEqual(store.rowerRecording?.measuredDistance, 500)
        XCTAssertEqual(RowingJourney(completions: store.state.completions).meters, 0)
        store.prepareReflection()
        XCTAssertTrue(store.complete(workout, seconds: 100, effort: 2, discomfort: false, note: "", manual: false))
        XCTAssertEqual(RowingJourney(completions: store.state.completions).meters, 500)
        XCTAssertFalse(store.complete(workout, seconds: 100, effort: 2, discomfort: false, note: "", manual: false))
        XCTAssertEqual(RowingJourney(completions: store.state.completions).meters, 500)
        let archive = try TrainingArchive.decode(TrainingArchive(state: store.state).encoded())
        let restored = await store.restoreTraining(archive)
        XCTAssertTrue(restored)
        XCTAssertEqual(RowingJourney(completions: store.state.completions).meters, 500)
        let saved = try XCTUnwrap(store.state.completions.first)
        var edit = RecordedWorkoutEdit(saved); edit.durationSeconds = 120; edit.note = "Edited"
        XCTAssertTrue(store.updateCompletion(saved, with: edit))
        XCTAssertEqual(RowingJourney(completions: store.state.completions).meters, 500)
        XCTAssertTrue(store.deleteCompletion(try XCTUnwrap(store.state.completions.first)))
        XCTAssertEqual(RowingJourney(completions: store.state.completions).meters, 0)
    }

    func testDeleteSavedCompletionPersistsAndReopensPlanWithoutRemovingOtherRecords() throws {
        let store = try makeStore()
        let plan = try XCTUnwrap(store.state.plan)
        let workout = plan.workouts[0]
        var recording = RowerRecording(deviceID: UUID(), deviceName: "Test PM5")
        recording.receive(.init(date: Date(), general: .init(elapsed: 1, distance: 4)), workoutElapsed: 1)
        let deleted = WorkoutCompletion(workout: workout, durationSeconds: workout.totalSeconds,
                                        effort: 3, discomfort: true, note: "Delete", manuallyRecorded: false, pm5: recording)
        let kept = WorkoutCompletion(workout: plan.workouts[1], durationSeconds: plan.workouts[1].totalSeconds,
                                     effort: 2, discomfort: false, note: "Keep", manuallyRecorded: true)
        store.update { $0.completions = [deleted, kept]; $0.checkedInCompletionID = deleted.id }
        let token = store.watchControlToken
        let revisions = store.state.revisions.map(\.id)
        XCTAssertTrue(store.deleteCompletion(deleted))
        let reopened = try RowivoStore(container: store.container)
        XCTAssertEqual(reopened.state.completions, [kept])
        XCTAssertEqual(reopened.state.plan, plan)
        XCTAssertEqual(reopened.state.revisions.map(\.id), revisions)
        XCTAssertEqual(reopened.nextWorkout?.id, workout.id)
        XCTAssertNil(reopened.state.checkedInCompletionID)
        XCTAssertNotEqual(store.watchControlToken, token)
        let exported = try TrainingArchive(state: reopened.state)
        XCTAssertEqual(exported.completions, [kept])
    }

    func testDeletingPartialRecordingKeepsFullCompletionAndCheckIn() throws {
        let store = try makeStore(), workout = try XCTUnwrap(store.nextWorkout)
        let partial = WorkoutCompletion(workout: workout, durationSeconds: 20, effort: 2, discomfort: false, note: "", manuallyRecorded: true)
        let full = WorkoutCompletion(workout: workout, durationSeconds: workout.totalSeconds, effort: 2, discomfort: true, note: "", manuallyRecorded: true)
        store.update { $0.completions = [partial, full]; $0.checkedInCompletionID = full.id }
        let next = store.nextWorkout
        XCTAssertTrue(store.deleteCompletion(partial))
        XCTAssertEqual(store.nextWorkout, next)
        XCTAssertEqual(store.state.checkedInCompletionID, full.id)
        XCTAssertEqual(store.state.completions, [full])
    }

    func testDeleteRejectsStaleRepeatedAndActiveSessionRequests() throws {
        let store = try makeStore(), workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: 20, effort: 2, discomfort: false, note: "", manual: true))
        let original = try XCTUnwrap(store.state.completions.first)
        var edit = RecordedWorkoutEdit(original); edit.note = "Changed after opening confirmation"
        XCTAssertTrue(store.updateCompletion(original, with: edit))
        let current = try XCTUnwrap(store.state.completions.first)
        XCTAssertFalse(store.deleteCompletion(original))
        store.start(workout, acknowledgingRecentTraining: true)
        XCTAssertNotNil(store.state.clock)
        XCTAssertFalse(store.deleteCompletion(current))
        XCTAssertEqual(store.state.completions, [current])
        store.discardTimer()
        XCTAssertTrue(store.deleteCompletion(current))
        XCTAssertFalse(store.deleteCompletion(current))
        XCTAssertTrue(store.state.completions.isEmpty)
    }

    func testProfileEditPersistsWithoutReplacingPlanHistoryOrActiveSession() throws {
        let store = try makeStore()
        let first = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(first, seconds: first.totalSeconds, effort: 2, discomfort: false, note: "Keep me", manual: true,
                                     trainedAt: Date().addingTimeInterval(-4 * 86400)))
        store.start(try XCTUnwrap(store.nextWorkout))
        let plan = store.state.plan, logs = store.state.completions, clock = store.state.clock
        let revisions = store.state.revisions.map(\.id)
        let original = try XCTUnwrap(store.state.profile)
        let token = store.watchControlToken
        var edited = original
        edited.name = "  Robin  "; edited.goal = .endurance; edited.experience = .returning; edited.sessionMinutes = 40
        XCTAssertTrue(store.updateProfile(edited, replacing: original))
        let reopened = try RowivoStore(container: store.container)
        XCTAssertEqual(reopened.state.profile?.name, "Robin")
        XCTAssertEqual(reopened.state.profile?.goal, .endurance)
        XCTAssertEqual(reopened.state.profile?.experience, .returning)
        XCTAssertEqual(reopened.state.profile?.sessionMinutes, 40)
        XCTAssertEqual(reopened.state.plan, plan); XCTAssertEqual(reopened.state.completions, logs)
        XCTAssertEqual(reopened.state.clock, clock); XCTAssertEqual(reopened.state.revisions.map(\.id), revisions)
        XCTAssertNotEqual(store.watchControlToken, token)
        let draft = WorkoutEditorRequest.new(plan: try XCTUnwrap(plan), minutes: 40, blockID: nil)
        XCTAssertEqual(draft.workout.totalSeconds, 2400)
        XCTAssertEqual(try TrainingArchive.decode(TrainingArchive(state: reopened.state).encoded()).profile, reopened.state.profile)
    }

    func testProfileEditRejectsInvalidAndStaleDraftsAndNoOpDoesNotRotateControls() throws {
        let store = try makeStore()
        let original = try XCTUnwrap(store.state.profile)
        let token = store.watchControlToken
        XCTAssertTrue(store.updateProfile(original, replacing: original))
        XCTAssertEqual(store.watchControlToken, token)
        for name in ["  ", String(repeating: "a", count: 201)] {
            var invalid = original; invalid.name = name
            XCTAssertFalse(store.updateProfile(invalid, replacing: original))
        }
        for minutes in [0, 61] {
            var invalid = original; invalid.sessionMinutes = minutes
            XCTAssertFalse(store.updateProfile(invalid, replacing: original))
        }
        XCTAssertEqual(store.state.profile, original)
        var firstEdit = original; firstEdit.name = "Robin"
        XCTAssertTrue(store.updateProfile(firstEdit, replacing: original))
        var stale = original; stale.name = "Outdated"
        XCTAssertFalse(store.updateProfile(stale, replacing: original))
        XCTAssertEqual(store.state.profile, firstEdit)
    }

    func testRecentTrainingRequiresConfirmationButConfirmedSessionCanSaveAndRelaunch() throws {
        let store = try makeStore()
        let first = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(first, seconds: first.totalSeconds, effort: 2, discomfort: false, note: "", manual: true))
        let next = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.canTrain); XCTAssertTrue(store.requiresRecentTrainingConfirmation)
        store.start(next)
        XCTAssertNil(store.state.clock)
        XCTAssertFalse(store.complete(next, seconds: 60, effort: 2, discomfort: false, note: "", manual: false))
        store.start(next, acknowledgingRecentTraining: true, expectedControlToken: store.watchControlToken)
        XCTAssertEqual(store.state.clock?.workoutID, next.id)
        store.toggleTimer(); store.toggleTimer(); store.toggleTimer()
        let reopened = try RowivoStore(container: store.container)
        XCTAssertTrue(reopened.complete(next, seconds: 60, effort: 2, discomfort: false, note: "Confirmed", manual: false))
        XCTAssertEqual(reopened.state.completions.count, 2)
        XCTAssertEqual(reopened.state.completions.last?.note, "Confirmed")
        XCTAssertNil(reopened.state.clock)
        reopened.start(next)
        XCTAssertNil(reopened.state.clock) // Each new start requires a fresh decision.
    }

    func testStartConfirmationCannotApplyToChangedStateOrSkipDiscomfortCheckIn() throws {
        let store = try makeStore()
        let first = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(first, seconds: first.totalSeconds, effort: 2, discomfort: false, note: "", manual: true))
        let next = try XCTUnwrap(store.nextWorkout)
        let token = store.watchControlToken
        store.addBlock()
        store.start(next, acknowledgingRecentTraining: true, expectedControlToken: token)
        XCTAssertNil(store.state.clock)
        store.update { $0.completions[0].discomfort = true }
        store.start(next, acknowledgingRecentTraining: true, expectedControlToken: store.watchControlToken)
        XCTAssertNil(store.state.clock)
        XCTAssertTrue(store.needsCheckIn)
        store.checkIn()
        store.start(next, acknowledgingRecentTraining: true, expectedControlToken: store.watchControlToken)
        XCTAssertEqual(store.state.clock?.workoutID, next.id)
    }

    func testAllSavedSessionFieldsPersistWithoutDuplicatingOrChangingPlanAndPM5() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = ModelConfiguration(url: root.appendingPathComponent("edit.store"), cloudKitDatabase: .none)
        let store = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        store.createProfile(.init(name: "Alex"), useTemplate: true)
        let plan = try XCTUnwrap(store.state.plan)
        let date = Date().addingTimeInterval(-2 * 86400)
        var recording = RowerRecording(deviceID: UUID(), deviceName: "PM5 Test")
        recording.receive(.init(date: date, general: .init(elapsed: 0, distance: 0)), workoutElapsed: 0)
        recording.receive(.init(date: date.addingTimeInterval(1), general: .init(elapsed: 1, distance: 4), heartRate: 130), workoutElapsed: 1)
        recording.breakContinuity(isGap: false)
        let originals = [
            WorkoutCompletion(workout: plan.workouts[0], date: date, durationSeconds: 1800, effort: 2, discomfort: false, note: "Typo", manuallyRecorded: true),
            WorkoutCompletion(workout: plan.workouts[1], date: date, durationSeconds: 1800, effort: 2, discomfort: false, note: "Timed typo", manuallyRecorded: false, recordedAt: Date()),
            WorkoutCompletion(workout: plan.workouts[2], date: date, durationSeconds: 1800, effort: 2, discomfort: false, note: "PM5 typo", manuallyRecorded: false, pm5: recording)
        ]
        store.update { $0.completions = originals }
        for (index, original) in originals.enumerated() {
            var edit = RecordedWorkoutEdit(original)
            edit.name = "Corrected \(index)"; edit.kind = .recovery
            edit.date = date.addingTimeInterval(-86400 + 97)
            edit.durationSeconds = 27 * 60 + 30; edit.effort = 4
            edit.discomfort = true; edit.note = "Corrected note \(index)\nSecond line"
            XCTAssertTrue(store.updateCompletion(original, with: edit))
        }
        let reopened = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertEqual(reopened.state.plan, plan)
        XCTAssertEqual(reopened.state.revisions.count, 1)
        XCTAssertEqual(reopened.state.completions.count, 3)
        for (index, log) in reopened.state.completions.enumerated() {
            XCTAssertEqual(log.id, originals[index].id); XCTAssertEqual(log.workoutID, originals[index].workoutID)
            XCTAssertEqual(log.customName, "Corrected \(index)"); XCTAssertEqual(log.title, .recovery)
            XCTAssertEqual(log.date, date.addingTimeInterval(-86400 + 97))
            XCTAssertEqual(log.durationSeconds, 1650); XCTAssertEqual(log.effort, 4)
            XCTAssertTrue(log.discomfort); XCTAssertEqual(log.note, "Corrected note \(index)\nSecond line")
            XCTAssertEqual(log.recordedAt, originals[index].recordedAt ?? originals[index].date)
            XCTAssertNotNil(log.editedAt)
            XCTAssertEqual(log.pm5, originals[index].pm5)
            XCTAssertEqual(log.manuallyRecorded, originals[index].manuallyRecorded)
            XCTAssertEqual(log.finishedPlan, log.durationSeconds >= plan.workouts[index].totalSeconds)
        }
        XCTAssertEqual(try TrainingArchive.decode(TrainingArchive(state: reopened.state).encoded()).completions, reopened.state.completions)
    }

    func testCorrectedDurationReopensAndCompletesPlanWithoutLosingOtherSessions() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: 60, effort: 2, discomfort: false, note: "First attempt", manual: true))
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "Second attempt", manual: true))
        let partial = store.state.completions[0]
        let full = store.state.completions[1]
        var edit = RecordedWorkoutEdit(partial); edit.durationSeconds = workout.totalSeconds + 30
        XCTAssertTrue(store.updateCompletion(partial, with: edit))
        XCTAssertEqual(store.state.completions.filter(\.finishedPlan).count, 2)
        XCTAssertNotEqual(store.nextWorkout?.id, workout.id)
        let archive = try TrainingArchive(state: store.state)
        XCTAssertNoThrow(try TrainingArchive.decode(archive.encoded()))
        var shortened = RecordedWorkoutEdit(full); shortened.durationSeconds = 30
        XCTAssertTrue(store.updateCompletion(full, with: shortened))
        XCTAssertNotEqual(store.nextWorkout?.id, workout.id) // The corrected first session still completes it.
        let corrected = store.state.completions[0]
        shortened = RecordedWorkoutEdit(corrected); shortened.durationSeconds = 30
        XCTAssertTrue(store.updateCompletion(corrected, with: shortened))
        XCTAssertEqual(store.nextWorkout?.id, workout.id)
        XCTAssertEqual(store.state.completions.count, 2)
        XCTAssertTrue(store.state.completions.allSatisfy { !$0.finishedPlan })
    }

    func testFullEditRejectsInvalidAndStaleDraftsAndKeepsNoOpUnchanged() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "Original", manual: true,
                                     trainedAt: Date().addingTimeInterval(-4 * 86400)))
        let original = store.state.completions[0]
        XCTAssertTrue(store.updateCompletion(original, with: RecordedWorkoutEdit(original)))
        XCTAssertEqual(store.state.completions, [original]); XCTAssertNil(store.state.completions[0].editedAt)
        var invalids: [RecordedWorkoutEdit] = []
        for duration in [0, -1, 14_401, Int.max] { var e = RecordedWorkoutEdit(original); e.durationSeconds = duration; invalids.append(e) }
        for effort in [0, 6] { var e = RecordedWorkoutEdit(original); e.effort = effort; invalids.append(e) }
        for date in [Date().addingTimeInterval(86400), Date(timeIntervalSinceReferenceDate: .nan)] { var e = RecordedWorkoutEdit(original); e.date = date; invalids.append(e) }
        var e = RecordedWorkoutEdit(original); e.name = String(repeating: "x", count: 81); invalids.append(e)
        e = RecordedWorkoutEdit(original); e.note = String(repeating: "x", count: 20_001); invalids.append(e)
        for edit in invalids {
            XCTAssertFalse(store.updateCompletion(original, with: edit))
            XCTAssertEqual(store.state.completions, [original])
        }
        e = RecordedWorkoutEdit(original); e.note = "Fixed"
        XCTAssertTrue(store.updateCompletion(original, with: e))
        XCTAssertFalse(store.updateCompletion(original, with: RecordedWorkoutEdit(original)))
        XCTAssertEqual(store.state.completions[0].note, "Fixed")
        let corrected = store.state.completions[0]
        store.start(try XCTUnwrap(store.nextWorkout))
        XCTAssertFalse(store.updateCompletion(corrected, with: e))
        XCTAssertEqual(store.state.completions, [corrected])
    }

    func testEditingDiscomfortUpdatesCheckInWithoutResettingUnrelatedCorrections() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "", manual: true))
        store.checkIn()
        var original = store.state.completions[0]
        var edit = RecordedWorkoutEdit(original); edit.discomfort = true
        XCTAssertTrue(store.updateCompletion(original, with: edit))
        XCTAssertTrue(store.needsCheckIn); XCTAssertNil(store.state.checkedInCompletionID)
        store.checkIn(); XCTAssertFalse(store.needsCheckIn)
        original = store.state.completions[0]; edit = RecordedWorkoutEdit(original); edit.note = "Typo fixed"
        XCTAssertTrue(store.updateCompletion(original, with: edit))
        XCTAssertFalse(store.needsCheckIn)
        original = store.state.completions[0]; edit = RecordedWorkoutEdit(original); edit.discomfort = false
        XCTAssertTrue(store.updateCompletion(original, with: edit))
        XCTAssertFalse(store.needsCheckIn)
    }

    func testUpgradeRemovesRetiredCredentialsWithoutChangingTraining() throws {
        let container = try ModelContainer(for: StoredState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let original = try RowivoStore(container: container)
        XCTAssertTrue(original.createProfile(.init(name: "Keep my training"), useTemplate: true))
        let workout = try XCTUnwrap(original.nextWorkout)
        XCTAssertTrue(original.complete(workout, seconds: workout.totalSeconds, effort: 3, discomfort: false, note: "Keep feedback", manual: true))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(original.state)
        var removals = 0
        let upgraded = try RowivoStore(container: container, removeRetiredCredentials: { removals += 1 })
        XCTAssertEqual(removals, 1)
        XCTAssertEqual(try encoder.encode(upgraded.state), before)
        XCTAssertNil(upgraded.errorMessage)
        let failed = try RowivoStore(container: container, removeRetiredCredentials: { throw CocoaError(.fileWriteUnknown) })
        XCTAssertEqual(try encoder.encode(failed.state), before)
        XCTAssertNotNil(failed.errorMessage)
        let retried = try RowivoStore(container: container, removeRetiredCredentials: { removals += 1 })
        XCTAssertEqual(removals, 2)
        XCTAssertEqual(try encoder.encode(retried.state), before)
        XCTAssertNil(retried.errorMessage)
    }

    func testRetiredCredentialDeletionIsIdempotentAndScoped() throws {
        let service = "rowivo-test-retired-" + UUID().uuidString
        let other = service + "-unrelated"
        func query(_ service: String) -> [String: Any] {
            [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
             kSecAttrAccount as String: "api-key"]
        }
        defer { SecItemDelete(query(service) as CFDictionary); SecItemDelete(query(other) as CFDictionary) }
        for name in [service, other] {
            var value = query(name)
            value[kSecValueData as String] = Data("synthetic-test-key".utf8)
            XCTAssertEqual(SecItemAdd(value as CFDictionary, nil), errSecSuccess)
        }
        try RowivoStore.removeLegacyCredential(services: [service])
        XCTAssertEqual(SecItemCopyMatching(query(service) as CFDictionary, nil), errSecItemNotFound)
        XCTAssertEqual(SecItemCopyMatching(query(other) as CFDictionary, nil), errSecSuccess)
        try RowivoStore.removeLegacyCredential(services: [service])
    }

    func testResetDeletesPersistentTrainingAndPrivateFilesButKeepsExportedCopies() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration(url: directory.appendingPathComponent("reset.store"), cloudKitDatabase: .none)
        let files = ArchiveFiles(temporaryDirectory: directory.appendingPathComponent("staging"))
        var credentialDeleted = false
        let store = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config), archiveFiles: files,
                                   deleteLegacyCredential: { credentialDeleted = true })
        XCTAssertTrue(store.createProfile(.init(name: "Private name"), useTemplate: true))
        let first = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(first, seconds: first.totalSeconds, effort: 3, discomfort: false, note: "Private note", manual: true,
                                     trainedAt: Date().addingTimeInterval(-5 * 86400)))
        let archive = try TrainingArchive(state: store.state)
        let restored = await store.restoreTraining(archive)
        XCTAssertTrue(restored)
        let recoveryDirectory = directory.appendingPathComponent("RowivoRestoreRecovery")
        XCTAssertTrue(FileManager.default.fileExists(atPath: recoveryDirectory.path))
        let staged = try await files.prepareExport(archive)
        let external = directory.appendingPathComponent("user-chosen-folder")
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        await store.chooseCloudFolder(external)
        await store.exportToFolder()
        let exportedName = try XCTUnwrap(store.state.cloudExport?.lastSnapshotName)
        let exportedBackup = external.appendingPathComponent(exportedName).appendingPathComponent("training.rowivo")
        store.start(try XCTUnwrap(store.nextWorkout))
        let device = RowerDevice(id: UUID(), name: "PM5 Private", signal: -50)
        store.receiveRower(.init(date: Date(), general: .init(elapsed: 0, distance: 0)), device: device)
        XCTAssertNotNil(store.state.clock)
        XCTAssertNotNil(store.rowerRecording)
        store.update {
            $0.messages = [.init(role: .user, text: "Legacy private chat")]
            $0.hasAIConsent = true; $0.checkedInCompletionID = $0.completions.first?.id
            $0.cloudExport?.automaticallyExport = true; $0.cloudExport?.pending = true
        }
        let deleted = await store.deleteAllData()
        XCTAssertTrue(deleted)
        XCTAssertTrue(credentialDeleted)
        XCTAssertNil(store.state.profile); XCTAssertNil(store.state.plan)
        XCTAssertTrue(store.state.completions.isEmpty); XCTAssertTrue(store.state.messages.isEmpty)
        XCTAssertTrue(store.state.revisions.isEmpty); XCTAssertNil(store.state.clock)
        XCTAssertNil(store.state.currentPM5Recording); XCTAssertNil(store.state.cloudExport)
        XCTAssertNil(store.state.restoreRecoveryName); XCTAssertNil(store.state.checkedInCompletionID)
        XCTAssertFalse(store.state.hasAIConsent); XCTAssertNil(store.state.pendingAdjustment)
        XCTAssertNil(store.rowerRecording); XCTAssertNil(store.rower.selectedDevice)
        XCTAssertNil(store.rower.lockedDeviceID); XCTAssertTrue(store.rower.devices.isEmpty)
        XCTAssertEqual(store.rower.state, .idle); XCTAssertFalse(store.showingWorkout)
        XCTAssertFalse(store.isDeletingData); XCTAssertFalse(store.isTransferringFiles)
        XCTAssertEqual(try store.container.mainContext.fetchCount(FetchDescriptor<StoredState>()), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recoveryDirectory.path))
        for url in staged { XCTAssertFalse(FileManager.default.fileExists(atPath: url.path)) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedBackup.path))
        let preserved = try await files.readBackup(exportedBackup)
        XCTAssertEqual(preserved.completions, archive.completions)
        // A late file-picker callback must not leave a misleading success message after reset.
        await store.finishFileExport(staged, saved: true)
        XCTAssertNil(store.storageMessage)
        let reopened = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertNil(reopened.state.profile); XCTAssertNil(reopened.state.clock)
        XCTAssertTrue(reopened.state.completions.isEmpty)
        XCTAssertTrue(reopened.createProfile(.init(name: "Fresh start")))
        XCTAssertEqual(reopened.state.plan?.workouts.count, 0)
        XCTAssertNil(reopened.state.cloudExport)
    }

    func testResetFailureIsReportedAndCanBeRetriedWithoutAcceptingEditsDuringDeletion() async throws {
        let container = try ModelContainer(for: StoredState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var shouldFail = true
        var activeStore: RowivoStore?
        let store = try RowivoStore(container: container, deleteLegacyCredential: {
            XCTAssertTrue(activeStore?.isDeletingData == true)
            XCTAssertFalse(activeStore!.createProfile(.init(name: "Concurrent edit")))
            if shouldFail { throw CocoaError(.fileWriteUnknown) }
        })
        activeStore = store
        XCTAssertTrue(store.createProfile(.init(name: "Keep until reset completes")))
        let rejected = await store.deleteAllData()
        XCTAssertFalse(rejected)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.state.profile?.name, "Keep until reset completes")
        XCTAssertFalse(store.isDeletingData); XCTAssertFalse(store.isTransferringFiles)
        shouldFail = false
        let deleted = await store.deleteAllData()
        XCTAssertTrue(deleted)
        XCTAssertNil(store.state.profile); XCTAssertNil(store.errorMessage)
        activeStore = nil
    }

    func testMultipleActualRecordingsKeepTheirPlannedTargetsAfterDateCorrection() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        let date = Date().addingTimeInterval(-4 * 86400)
        XCTAssertTrue(store.complete(workout, seconds: 600, effort: 3, discomfort: false, note: "Short row", manual: true, trainedAt: date))
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds + 60, effort: 4, discomfort: false, note: "Long row", manual: true))
        let first = store.recordings(for: workout.id)[1]
        let completed = store.recordings(for: workout.id)[0]
        XCTAssertEqual(store.latestCompletion?.id, completed.id)
        XCTAssertTrue(store.updateCompletionDate(completed, to: date.addingTimeInterval(-86400)))
        XCTAssertEqual(store.recordings(for: workout.id).map(\.id), [first.id, completed.id])
        XCTAssertEqual(store.latestCompletion?.durationSeconds, 600)
        XCTAssertEqual(store.state.plan?.workouts.first, workout)
        XCTAssertNotEqual(store.nextWorkout?.id, workout.id)
    }

    func testExistingDatesPersistWithoutChangingLegacyPM5OrWorkoutData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration(url: directory.appendingPathComponent("history.store"), cloudKitDatabase: .none)
        let store = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        store.createProfile(.init(name: "Alex"), useTemplate: true)
        let plan = try XCTUnwrap(store.state.plan)
        let now = Date()
        let originalDate = now.addingTimeInterval(-86400)
        var recording = RowerRecording(deviceID: UUID(), deviceName: "PM5 TEST")
        recording.receive(.init(date: originalDate, general: .init(elapsed: 0, distance: 0)), workoutElapsed: 0)
        recording.receive(.init(date: originalDate.addingTimeInterval(1), general: .init(elapsed: 1, distance: 4), heartRate: 130), workoutElapsed: 1)
        recording.breakContinuity(isGap: false) // A saved recording has no live sampling baseline.
        let original = [
            WorkoutCompletion(workout: plan.workouts[0], date: originalDate, durationSeconds: 120, effort: 3, discomfort: true, note: "Legacy PM5", manuallyRecorded: false, pm5: recording),
            WorkoutCompletion(workout: plan.workouts[1], date: originalDate, durationSeconds: plan.workouts[1].totalSeconds, effort: 2, discomfort: false, note: "Timer", manuallyRecorded: false, recordedAt: now),
            WorkoutCompletion(workout: plan.workouts[2], date: originalDate, durationSeconds: plan.workouts[2].totalSeconds, effort: 2, discomfort: false, note: "Manual", manuallyRecorded: true, recordedAt: now)
        ]
        store.update { $0.completions = original }
        var expected = original
        for index in original.indices {
            let date = now.addingTimeInterval(Double(-4 - index) * 86400)
            XCTAssertTrue(store.updateCompletionDate(original[index], to: date))
            expected[index].recordedAt = original[index].recordedAt ?? original[index].date
            expected[index].date = date
            expected[index].editedAt = store.state.completions[index].editedAt
            XCTAssertNotNil(expected[index].editedAt)
        }
        let reopened = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertEqual(reopened.state.completions, expected)
        XCTAssertEqual(reopened.state.completions[0].pm5, recording)
        XCTAssertEqual(reopened.state.plan, plan)
        XCTAssertEqual(reopened.state.revisions.count, 1)
        XCTAssertEqual(try TrainingArchive.decode(TrainingArchive(state: reopened.state).encoded()).completions, expected)
    }

    func testDateCorrectionsUpdateRecoveryAndKeepOriginalCaptureTime() throws {
        let store = try makeStore()
        let plan = try XCTUnwrap(store.state.plan)
        let now = Date()
        let healthy = WorkoutCompletion(workout: plan.workouts[0], date: now.addingTimeInterval(-4 * 86400), durationSeconds: 60, effort: 2, discomfort: false, note: "", manuallyRecorded: true)
        let discomfort = WorkoutCompletion(workout: plan.workouts[1], date: now, durationSeconds: 60, effort: 2, discomfort: true, note: "", manuallyRecorded: true, recordedAt: now)
        store.update { $0.completions = [healthy, discomfort] }
        let next = store.nextWorkout
        XCTAssertTrue(store.needsCheckIn)
        XCTAssertFalse(store.canTrain)
        XCTAssertTrue(store.updateCompletionDate(discomfort, to: now.addingTimeInterval(-5 * 86400)))
        XCTAssertFalse(store.needsCheckIn)
        XCTAssertTrue(store.canTrain)
        // Corrections may also move a previously saved date forward, up to today.
        XCTAssertTrue(store.updateCompletionDate(healthy, to: now))
        XCTAssertTrue(store.canTrain); XCTAssertTrue(store.requiresRecentTrainingConfirmation)
        XCTAssertEqual(store.state.completions[0].recordedAt, healthy.date)
        XCTAssertEqual(store.nextWorkout, next)
        XCTAssertEqual(store.state.plan, plan)
        XCTAssertNoThrow(try TrainingArchive(state: store.state).validate())
    }

    func testExistingDateEditRejectsStaleInvalidAndActiveEdits() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        let date = Date().addingTimeInterval(-4 * 86400)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "", manual: true, trainedAt: date))
        let original = try XCTUnwrap(store.state.completions.first)
        for invalid in [Date().addingTimeInterval(3600), Date(timeIntervalSinceReferenceDate: .nan)] {
            XCTAssertFalse(store.updateCompletionDate(original, to: invalid))
            XCTAssertEqual(store.state.completions, [original])
        }
        XCTAssertTrue(store.updateCompletionDate(original, to: date.addingTimeInterval(-86400)))
        let edited = try XCTUnwrap(store.state.completions.first)
        XCTAssertFalse(store.updateCompletionDate(original, to: date))
        var missing = edited; missing.id = UUID()
        XCTAssertFalse(store.updateCompletionDate(missing, to: date))
        store.start(try XCTUnwrap(store.nextWorkout))
        let clock = try XCTUnwrap(store.state.clock)
        XCTAssertFalse(store.updateCompletionDate(edited, to: date))
        XCTAssertEqual(store.state.clock, clock)
        XCTAssertEqual(store.state.completions, [edited])
    }

    func testBackdatedSessionsPersistAndUseWorkoutDateForRecovery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration(url: directory.appendingPathComponent("dates.store"), cloudKitDatabase: .none)
        let store = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        store.createProfile(.init(name: "Alex"), useTemplate: true)
        let before = Date()
        let older = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -4, to: before))
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "Four days ago", manual: true, trainedAt: older))
        XCTAssertEqual(store.state.completions[0].date, older)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(store.state.completions[0].recordedAt), before)
        XCTAssertTrue(store.canTrain) // Saving today must not create a new rest day for an old workout.

        let today = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(today, seconds: today.totalSeconds, effort: 2, discomfort: true, note: "Today", manual: true))
        let available = PlanEngine.availableDate(completions: store.state.completions)
        XCTAssertFalse(store.canTrain)
        let middleDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -2, to: before))
        let middle = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(middle, seconds: middle.totalSeconds, effort: 2, discomfort: false, note: "Backfilled during a rest day", manual: true, trainedAt: middleDate))
        XCTAssertEqual(PlanEngine.availableDate(completions: store.state.completions), available)
        XCTAssertTrue(store.needsCheckIn) // An older entry must not hide the latest discomfort report.
        XCTAssertFalse(store.canTrain)
        store.start(try XCTUnwrap(store.nextWorkout))
        XCTAssertNil(store.state.clock)

        let reopened = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertEqual(reopened.state.completions, store.state.completions)
        XCTAssertEqual(reopened.state.completions.sorted { $0.date > $1.date }.map(\.note), ["Today", "Backfilled during a rest day", "Four days ago"])
    }

    func testInvalidDatesAndBackdatingTimedSessionsAreRejected() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        for date in [Date().addingTimeInterval(3600), Date(timeIntervalSinceReferenceDate: .nan)] {
            XCTAssertFalse(store.complete(workout, seconds: 60, effort: 2, discomfort: false, note: "", manual: true, trainedAt: date))
        }
        XCTAssertFalse(store.complete(workout, seconds: 60, effort: 2, discomfort: false, note: "", manual: false, trainedAt: Date().addingTimeInterval(-86400)))
        XCTAssertTrue(store.state.completions.isEmpty)
        store.start(workout)
        let clock = store.state.clock
        XCTAssertFalse(store.complete(workout, seconds: 60, effort: 2, discomfort: false, note: "", manual: true, trainedAt: Date().addingTimeInterval(-86400)))
        XCTAssertEqual(store.state.clock, clock)
        XCTAssertTrue(store.state.completions.isEmpty)
    }

    func testEmptyPlanAndCustomWorkoutPersistAcrossReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration(url: directory.appendingPathComponent("manual.store"), cloudKitDatabase: .none)
        let store = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertTrue(store.createProfile(.init(name: "Alex")))
        XCTAssertEqual(store.state.plan?.blocks.count, 0)
        let workout = Workout(kind: .intervals, segments: [.init(kind: .warmup, seconds: 60), .init(kind: .work, seconds: 90), .init(kind: .cooldown, seconds: 30)], customName: "  Morning row  ")
        XCTAssertTrue(store.saveWorkout(workout, replacing: nil, in: nil, baseRevision: 1))
        let reopened = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertEqual(reopened.nextWorkout?.customName, "Morning row")
        XCTAssertEqual(reopened.nextWorkout?.totalSeconds, 180)
        XCTAssertEqual(reopened.nextWorkout?.id, workout.id)
        XCTAssertEqual(reopened.state.revisions.count, 2)
    }

    func testRecordedWorkoutCannotBeEditedOrDeletedButCanBeDuplicated() throws {
        let store = try makeStore()
        var original = try XCTUnwrap(store.nextWorkout)
        let blockID = try XCTUnwrap(store.currentBlock?.id)
        original.customName = "First row"
        XCTAssertTrue(store.saveWorkout(original, replacing: original.id, in: blockID, baseRevision: 1))
        XCTAssertTrue(store.complete(original, seconds: 60, effort: 2, discomfort: false, note: "Partial", manual: true))
        let savedPlan = store.state.plan
        var edited = original; edited.segments[1].seconds = 60
        XCTAssertFalse(store.saveWorkout(edited, replacing: original.id, in: blockID, baseRevision: savedPlan!.revision))
        XCTAssertFalse(store.deleteWorkout(original.id))
        XCTAssertEqual(store.state.plan, savedPlan)
        let copy = ManualPlan.duplicate(original)
        XCTAssertTrue(store.saveWorkout(copy, replacing: nil, in: blockID, baseRevision: savedPlan!.revision))
        XCTAssertEqual(store.state.completions[0].customName, "First row")
        XCTAssertTrue(store.state.plan!.workouts.contains { $0.id == original.id })
        XCTAssertTrue(store.state.plan!.workouts.contains { $0.id == copy.id })
    }

    func testStaleEditorAndActiveTimerCannotChangePlan() throws {
        let store = try makeStore()
        let original = try XCTUnwrap(store.nextWorkout)
        let blockID = try XCTUnwrap(store.currentBlock?.id)
        store.addBlock()
        XCTAssertFalse(store.saveWorkout(original, replacing: original.id, in: blockID, baseRevision: 1))
        let plan = store.state.plan
        store.start(original)
        var edited = original; edited.customName = "Changed"
        XCTAssertFalse(store.saveWorkout(edited, replacing: original.id, in: blockID, baseRevision: plan!.revision))
        XCTAssertFalse(store.deleteWorkout(original.id))
        store.addBlock()
        XCTAssertEqual(store.state.plan, plan)
        XCTAssertEqual(store.state.clock?.workoutID, original.id)
    }

    func testManualOrderingAndRemovalSelectTheNextWorkout() throws {
        let store = try makeStore()
        let block = try XCTUnwrap(store.currentBlock)
        store.reorderWorkouts(in: block.id, from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(store.nextWorkout?.id, block.workouts[2].id)
        XCTAssertTrue(store.deleteWorkout(block.workouts[2].id))
        XCTAssertEqual(store.nextWorkout?.id, block.workouts[0].id)
        let revision = store.state.plan?.revision
        store.reorderWorkouts(in: block.id, from: IndexSet(integer: 99), to: 0)
        XCTAssertEqual(store.state.plan?.revision, revision)
        store.deleteEmptyBlock(block.id)
        XCTAssertEqual(store.state.plan?.revision, revision)
    }

    func testStaleCompletionCannotRecordAnEditedDefinition() throws {
        let store = try makeStore()
        let original = try XCTUnwrap(store.nextWorkout)
        var edited = original; edited.customName = "Edited"
        XCTAssertTrue(store.saveWorkout(edited, replacing: original.id, in: store.currentBlock?.id, baseRevision: 1))
        XCTAssertFalse(store.complete(original, seconds: original.totalSeconds, effort: 2, discomfort: false, note: "", manual: true))
        XCTAssertTrue(store.state.completions.isEmpty)
    }

    func testLegacyAIPermissionAndProposalAreDisabledOnReopen() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        store.update {
            $0.hasAIConsent = true
            $0.pendingAdjustment = .init(adjustment: .init(action: .easeNext, reason: "Old"), baseRevision: 1, nextWorkoutID: workout.id)
            $0.messages = [.init(role: .user, text: "Legacy local message")]
        }
        let reopened = try RowivoStore(container: store.container)
        XCTAssertFalse(reopened.state.hasAIConsent)
        XCTAssertNil(reopened.state.pendingAdjustment)
        XCTAssertEqual(reopened.state.messages.first?.text, "Legacy local message")
        XCTAssertEqual(reopened.state.plan, store.state.plan)
    }

    func testStoreRestoresProfileCompletedSessionAndTimerFromDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration(url: directory.appendingPathComponent("state.store"), cloudKitDatabase: .none)
        let first = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        first.createProfile(.init(name: "Alex"), useTemplate: true)
        let workout = try XCTUnwrap(first.nextWorkout)
        first.start(workout)
        first.toggleTimer()
        let second = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertEqual(second.state.profile?.name, "Alex")
        XCTAssertEqual(second.state.clock?.workoutID, workout.id)
        XCTAssertNil(second.state.clock?.resumedAt)
        XCTAssertTrue(second.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "Comfortable", manual: false))
        let third = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertEqual(third.state.completions.count, 1)
        XCTAssertEqual(third.state.completions.first?.note, "Comfortable")
        XCTAssertNil(third.state.clock)
        XCTAssertNotEqual(third.nextWorkout?.id, workout.id)
        XCTAssertTrue(third.canTrain); XCTAssertTrue(third.requiresRecentTrainingConfirmation)
    }

    func testPartialSessionDoesNotCompleteWorkout() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: 120, effort: 2, discomfort: false, note: "", manual: false))
        XCTAssertFalse(store.state.completions[0].finishedPlan)
        XCTAssertEqual(store.nextWorkout?.id, workout.id)
        XCTAssertTrue(store.canTrain); XCTAssertTrue(store.requiresRecentTrainingConfirmation)
    }

    func testDuplicateCompletionAndStartingFutureWorkoutAreRejected() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        let future = try XCTUnwrap(store.state.plan?.workouts.last)
        store.start(future)
        XCTAssertNil(store.state.clock)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: true, note: "", manual: true))
        XCTAssertFalse(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "", manual: true))
        XCTAssertEqual(store.state.completions.count, 1)
        XCTAssertTrue(store.needsCheckIn)
    }

    func testPM5RecordingSurvivesDatabaseReopenAndIsAttachedToCompletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration(url: directory.appendingPathComponent("pm5.store"), cloudKitDatabase: .none)
        let store = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        store.createProfile(.init(name: "Alex"), useTemplate: true)
        let workout = try XCTUnwrap(store.nextWorkout)
        let device = RowerDevice(id: UUID(), name: "PM5 TEST ONLY", signal: -40)
        store.start(workout)
        let now = Date()
        store.receiveRower(.init(date: now, general: .init(elapsed: 500, distance: 1500)), device: device)
        store.receiveRower(.init(date: now.addingTimeInterval(1), general: .init(elapsed: 501, distance: 1504), pace: 125, strokeRate: 22, watts: 180, heartRate: 130), device: device)
        store.toggleTimer() // Flushes the complete recording before presenting feedback.
        let reopened = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertEqual(reopened.rowerRecording?.distance, 4)
        XCTAssertEqual(reopened.rowerRecording?.samples.last?.watts, 180)
        XCTAssertEqual(reopened.rower.lockedDeviceID, device.id)
        XCTAssertTrue(reopened.rowerRecording?.hasGaps == true)
        XCTAssertTrue(reopened.complete(workout, seconds: 60, effort: 2, discomfort: false, note: "Test", manual: false))
        let saved = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        XCTAssertEqual(saved.state.completions.first?.pm5?.distance, 4)
        XCTAssertEqual(saved.state.completions.first?.pm5?.samples.last?.heartRate, 130)
        XCTAssertNil(saved.rowerRecording); XCTAssertNil(saved.state.currentPM5Recording)
    }

    func testPM5RecordingIgnoresPausedPacketsDifferentDevicesAndDiscardedData() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        let device = RowerDevice(id: UUID(), name: "PM5 TEST ONLY", signal: -40)
        let other = RowerDevice(id: UUID(), name: "PM5 OTHER TEST", signal: -40)
        let now = Date()
        func feed(_ seconds: Double, device: RowerDevice) {
            store.receiveRower(.init(date: now.addingTimeInterval(seconds), general: .init(elapsed: seconds, distance: seconds * 4)), device: device)
        }
        feed(0, device: device); XCTAssertNil(store.rowerRecording)
        store.start(workout)
        feed(1, device: device); feed(2, device: device)
        feed(3, device: other); XCTAssertEqual(store.rowerRecording?.distance, 4)
        store.toggleTimer(); feed(4, device: device)
        XCTAssertEqual(store.rowerRecording?.distance, 4)
        XCTAssertFalse(store.complete(workout, seconds: 60, effort: 2, discomfort: false, note: "", manual: true))
        store.discardTimer(); XCTAssertNil(store.rowerRecording); XCTAssertNil(store.state.currentPM5Recording)
        store.start(workout); feed(6, device: device); feed(7, device: device)
        XCTAssertEqual(store.rowerRecording?.distance, 4)
        XCTAssertEqual(store.rowerRecording?.samples.count, 2)
    }

    func testLegacyAppPayloadWithoutRecordingStillLoads() throws {
        let store = try makeStore()
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(store.state)) as? [String: Any])
        legacy.removeValue(forKey: "currentPM5Recording")
        let restored = try JSONDecoder().decode(AppState.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(restored.profile?.name, "Alex"); XCTAssertNil(restored.currentPM5Recording)
    }

    private func makeStore() throws -> RowivoStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let store = try RowivoStore(container: ModelContainer(for: StoredState.self, configurations: config))
        store.createProfile(.init(name: "Alex"), useTemplate: true)
        return store
    }
}
