import XCTest
import SwiftData
import RowivoCore
@testable import Rowivo

@MainActor final class ArchiveTests: XCTestCase {
    func testEmptyAndCustomPlansRoundTripInFormatFour() throws {
        let container = try ModelContainer(for: StoredState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let store = try RowivoStore(container: container)
        store.createProfile(.init(name: "Alex"))
        let empty = try TrainingArchive(state: store.state)
        XCTAssertEqual(try TrainingArchive.decode(empty.encoded()).plan.blocks.count, 0)
        XCTAssertNotNil(try empty.exportFiles()["plan.csv"])
        let workout = Workout(kind: .endurance, segments: [.init(kind: .work, seconds: 90)], customName: "=Morning row")
        XCTAssertTrue(store.saveWorkout(workout, replacing: nil, in: nil, baseRevision: 1))
        XCTAssertTrue(store.complete(workout, seconds: 90, effort: 2, discomfort: false, note: "", manual: true))
        let archive = try TrainingArchive(state: store.state)
        let decoded = try TrainingArchive.decode(archive.encoded())
        XCTAssertEqual(decoded.version, 4)
        XCTAssertEqual(decoded.plan.workouts.first?.customName, "=Morning row")
        XCTAssertEqual(decoded.completions.first?.customName, "=Morning row")
        for file in ["plan.csv", "sessions.csv"] {
            let text = String(decoding: try XCTUnwrap(archive.exportFiles()[file]), as: UTF8.self)
            XCTAssertTrue(text.contains("workout_name"))
            XCTAssertTrue(text.contains("'=Morning row"))
        }
    }

    func testOlderBackupsAndMissingOptionalFieldsStillDecode() throws {
        for version in [1, 2, 3] {
            var archive = try makeArchive(); archive.version = version
            let restored = try TrainingArchive.decode(archive.encoded())
            XCTAssertEqual(restored.plan, archive.plan)
            XCTAssertNil(restored.plan.workouts.first?.customName)
            XCTAssertNil(restored.completions.first?.customName)
            XCTAssertNil(restored.completions.first?.recordedAt)
            XCTAssertNil(restored.completions.first?.editedAt)
            XCTAssertEqual(restored.completions.first?.date, archive.completions.first?.date)
        }
    }

    func testBackdatedExportPreservesWorkoutAndRecordingTimestamps() throws {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        let trainedAt = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "", manual: true, trainedAt: trainedAt))
        let archive = try TrainingArchive(state: store.state)
        let restored = try TrainingArchive.decode(archive.encoded())
        XCTAssertEqual(restored.completions, store.state.completions)
        let recordedAt = try XCTUnwrap(restored.completions.first?.recordedAt)
        XCTAssertGreaterThan(recordedAt, trainedAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let csv = String(decoding: try XCTUnwrap(archive.exportFiles()["sessions.csv"]), as: UTF8.self)
        XCTAssertTrue(csv.contains("\"recorded_at_utc\""))
        XCTAssertTrue(csv.contains("\"trained_at_utc\""))
        XCTAssertTrue(csv.contains("\"\(workout.id.uuidString)\",\"\(formatter.string(from: recordedAt))\""))
        XCTAssertTrue(csv.hasSuffix(",\"\(formatter.string(from: trainedAt))\",\"\"\r\n"))
    }

    private func makeStore() throws -> RowivoStore {
        let container = try ModelContainer(for: StoredState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let store = try RowivoStore(container: container)
        store.createProfile(.init(name: "Alex"), useTemplate: true)
        return store
    }
    private func makeArchive() throws -> TrainingArchive {
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        var recording = PM5Recording(deviceID: UUID(), deviceName: "PM5 Test")
        recording.receive(.init(date: date, general: .init(elapsed: 0, distance: 0)), workoutElapsed: 0)
        recording.receive(.init(date: date.addingTimeInterval(1), general: .init(elapsed: 1, distance: 4), pace: 125, strokeRate: 22, watts: 180), workoutElapsed: 1)
        recording.breakContinuity(isGap: false)
        store.update {
            $0.completions = [.init(workout: workout, date: date, durationSeconds: workout.totalSeconds, effort: 2, discomfort: false,
                                    note: "=1+1", manuallyRecorded: false, pm5: recording)]
            $0.messages = [.init(role: .user, text: "PRIVATE_CHAT_SENTINEL")]
            $0.hasAIConsent = true
            $0.cloudExport = .init(bookmark: Data("PRIVATE_BOOKMARK".utf8), folderName: "PRIVATE_FOLDER")
        }
        return try TrainingArchive(state: store.state, at: date)
    }

    func testPortableBackupRoundTripAndPrivateFieldsExcluded() throws {
        let archive = try makeArchive()
        let data = try archive.encoded()
        let text = String(decoding: data, as: UTF8.self)
        for token in ["PRIVATE_CHAT_SENTINEL", "PRIVATE_BOOKMARK", "PRIVATE_FOLDER", "hasAIConsent", "cloudExport", "modelID", "currentPM5Recording"] {
            XCTAssertFalse(text.contains(token), token)
        }
        let restored = try TrainingArchive.decode(data)
        XCTAssertEqual(restored.plan, archive.plan)
        XCTAssertEqual(restored.completions, archive.completions)
        XCTAssertEqual(restored.completions[0].note, "=1+1") // CSV protection must not alter the backup.
        XCTAssertEqual(restored.revisions.count, 1)
    }

    func testCSVTablesJoinMeasuredSessionAndPreserveMissingReadings() throws {
        let archive = try makeArchive()
        let files = try archive.exportFiles()
        XCTAssertEqual(Set(files.keys), Set(["profile.csv", "sessions.csv", "pm5_samples.csv", "plan.csv", "training.rowivo", "README.txt"]))
        let sessions = String(decoding: try XCTUnwrap(files["sessions.csv"]), as: UTF8.self)
        let samples = String(decoding: try XCTUnwrap(files["pm5_samples.csv"]), as: UTF8.self)
        XCTAssertTrue(sessions.contains("\"'=1+1\""))
        XCTAssertTrue(sessions.contains("\"pm5\",\"PM5 Test\",\"4.0\",\"1.0\",\"125.0\""))
        XCTAssertTrue(samples.contains(archive.completions[0].id.uuidString))
        XCTAssertTrue(samples.contains("\"125.0\",\"22\",\"180\",\"\",\"0\""))
        XCTAssertEqual(samples.components(separatedBy: "\r\n").count, 4) // header, two samples, final terminator
        XCTAssertTrue(sessions.contains("Z\""))
    }

    func testMalformedUnsupportedAndUnsafeBackupRejected() throws {
        XCTAssertThrowsError(try TrainingArchive.decode(Data("truncated".utf8)))
        var archive = try makeArchive()
        archive.version = 999
        XCTAssertThrowsError(try TrainingArchive.decode(archive.encoded())) { XCTAssertEqual($0 as? StorageError, .newerBackup) }
        archive.version = 1
        archive.plan.blocks[0].workouts[0].segments[0].seconds = Int.max
        XCTAssertThrowsError(try TrainingArchive.decode(archive.encoded())) // no overflow in validation
        archive = try makeArchive()
        archive.completions.append(archive.completions[0])
        XCTAssertThrowsError(try TrainingArchive.decode(archive.encoded()))
    }

    func testFolderExportsCreateIndependentCompleteSnapshots() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = ArchiveFiles()
        let settings = try await files.rememberFolder(root)
        let archive = try makeArchive()
        let first = try await files.export(archive, bookmark: settings.bookmark)
        let second = try await files.export(archive, bookmark: settings.bookmark)
        XCTAssertNotEqual(first.folderName, second.folderName)
        for name in [first.folderName, second.folderName] {
            let directory = root.appendingPathComponent(name)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 7)
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("complete.json").path))
            let read = try await files.readBackup(directory.appendingPathComponent("training.rowivo"))
            XCTAssertEqual(read.completions, archive.completions)
        }
    }

    func testAutoExportRequiresOptInAndRetryKeepsLocalData() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore()
        await store.chooseCloudFolder(root)
        XCTAssertFalse(store.state.cloudExport!.automaticallyExport)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        store.setAutomaticExport(true)
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "", manual: true))
        XCTAssertTrue(store.state.cloudExport!.pending)
        await store.exportIfNeeded()
        XCTAssertNotNil(store.state.cloudExport?.lastExportAt)
        XCTAssertFalse(store.state.cloudExport!.pending)
        let lastDate = store.state.cloudExport?.lastExportAt
        try FileManager.default.removeItem(at: root)
        await store.exportToFolder()
        XCTAssertTrue(store.storageFailed)
        XCTAssertTrue(store.state.cloudExport!.pending)
        XCTAssertEqual(store.state.completions.count, 1)
        XCTAssertEqual(store.state.cloudExport?.lastExportAt, lastDate)
        store.disconnectCloudFolder()
        XCTAssertNil(store.state.cloudExport)
    }

    func testDateCorrectionTriggersCloudCopyWithoutAddingASession() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "Keep this", manual: true))
        await store.chooseCloudFolder(root)
        store.setAutomaticExport(true)
        await store.exportToFolder()
        XCTAssertFalse(store.state.cloudExport!.pending)
        let firstFolder = store.state.cloudExport?.lastSnapshotName
        let original = try XCTUnwrap(store.state.completions.first)
        let correctedDate = original.date.addingTimeInterval(-3 * 86400)
        XCTAssertTrue(store.updateCompletionDate(original, to: correctedDate))
        XCTAssertEqual(store.state.completions.count, 1)
        XCTAssertTrue(store.state.cloudExport!.pending)
        await store.exportIfNeeded()
        XCTAssertFalse(store.state.cloudExport!.pending)
        let folder = try XCTUnwrap(store.state.cloudExport?.lastSnapshotName)
        XCTAssertNotEqual(folder, firstFolder)
        let archive = try await ArchiveFiles().readBackup(root.appendingPathComponent(folder).appendingPathComponent("training.rowivo"))
        XCTAssertEqual(archive.completions.first?.date, correctedDate)
        XCTAssertEqual(archive.completions.first?.recordedAt, original.recordedAt)
        XCTAssertEqual(archive.completions.first?.note, original.note)
        XCTAssertEqual(archive.completions.count, 1)
    }

    func testFullCorrectionTriggersCloudCopyAndExportsCorrectedFields() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore()
        let workout = try XCTUnwrap(store.nextWorkout)
        XCTAssertTrue(store.complete(workout, seconds: workout.totalSeconds, effort: 2, discomfort: false, note: "Typo", manual: true))
        await store.chooseCloudFolder(root); store.setAutomaticExport(true)
        await store.exportToFolder()
        let previousFolder = store.state.cloudExport?.lastSnapshotName
        let original = store.state.completions[0]
        var edit = RecordedWorkoutEdit(original)
        edit.name = "=Corrected"; edit.kind = .intervals; edit.durationSeconds = 1830
        edit.effort = 4; edit.discomfort = true; edit.note = "Fixed, with comma\nand newline"
        XCTAssertTrue(store.updateCompletion(original, with: edit))
        XCTAssertTrue(store.state.cloudExport!.pending)
        await store.exportIfNeeded()
        let folder = try XCTUnwrap(store.state.cloudExport?.lastSnapshotName)
        XCTAssertNotEqual(folder, previousFolder)
        let directory = root.appendingPathComponent(folder)
        let restored = try await ArchiveFiles().readBackup(directory.appendingPathComponent("training.rowivo"))
        XCTAssertEqual(restored.completions, store.state.completions)
        XCTAssertEqual(restored.completions.count, 1)
        let csv = try String(contentsOf: directory.appendingPathComponent("sessions.csv"), encoding: .utf8)
        XCTAssertTrue(csv.contains("edited_at_utc"))
        XCTAssertTrue(csv.contains("\"1830\",\"4\",\"true\""))
        XCTAssertTrue(csv.contains("'=Corrected")); XCTAssertTrue(csv.contains(edit.note))
        XCTAssertEqual(restored.plan.workouts.first, workout)
    }

    func testRestoreIsExplicitTransactionalAndRecoverable() async throws {
        let store = try makeStore()
        let originalPlan = store.state.plan
        store.update { $0.messages = [.init(role: .user, text: "Keep local chat")]; $0.hasAIConsent = true }
        let archive = try makeArchive()
        XCTAssertEqual(store.state.completions.count, 0)
        let restored = await store.restoreTraining(archive)
        XCTAssertTrue(restored)
        XCTAssertEqual(store.state.completions, archive.completions)
        XCTAssertFalse(store.state.hasAIConsent)
        XCTAssertNil(store.state.cloudExport)
        XCTAssertNil(store.state.pendingAdjustment)
        XCTAssertEqual(store.state.messages.first?.text, "Keep local chat")
        let recovery = await store.inspectRecovery()
        XCTAssertEqual(recovery?.plan, originalPlan)
        XCTAssertEqual(recovery?.completions.count, 0)
        var invalid = archive; invalid.plan.blocks = []
        let rejected = await store.restoreTraining(invalid)
        XCTAssertFalse(rejected)
        XCTAssertEqual(store.state.plan, archive.plan)
    }

    func testActiveSessionPreventsExportAndRestore() async throws {
        let store = try makeStore()
        store.start(try XCTUnwrap(store.nextWorkout))
        let clock = store.state.clock
        let archive = try makeArchive()
        let restored = await store.restoreTraining(archive)
        let export = await store.prepareFileExport()
        XCTAssertFalse(restored); XCTAssertNil(export)
        XCTAssertEqual(store.state.clock, clock)
        XCTAssertTrue(store.state.completions.isEmpty)
    }
}
