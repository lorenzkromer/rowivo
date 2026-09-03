import Foundation
import Observation
import RowivoCore
import SwiftData
import Security

enum RecordedWorkoutEditError: Error { case activeWorkout, staleEntry, invalidDuration, invalidEffort, noteTooLong }

/// Only editable session details; identifiers, capture metadata and sensor samples are not drafts.
struct RecordedWorkoutEdit {
    var name: String
    var kind: WorkoutKind
    var date: Date
    var durationSeconds: Int
    var effort: Int
    var discomfort: Bool
    var note: String

    init(_ completion: WorkoutCompletion) {
        name = completion.customName ?? ""; kind = completion.title; date = completion.date
        durationSeconds = completion.durationSeconds; effort = completion.effort
        discomfort = completion.discomfort; note = completion.note
    }

    func validate() throws {
        guard date.timeIntervalSinceReferenceDate.isFinite, date <= Date() else { throw PlanError.invalidTrainingDate }
        guard (1...14_400).contains(durationSeconds) else { throw RecordedWorkoutEditError.invalidDuration }
        guard (1...5).contains(effort) else { throw RecordedWorkoutEditError.invalidEffort }
        guard name.trimmingCharacters(in: .whitespacesAndNewlines).count <= 80 else { throw ManualPlanError.nameTooLong }
        guard note.count <= 20_000 else { throw RecordedWorkoutEditError.noteTooLong }
    }
}

@MainActor @Observable final class RowivoStore {
    private(set) var state: AppState
    var errorMessage: String?
    var showingWorkout = false
    let pm5 = PM5Connection()
    private(set) var pm5Recording: PM5Recording?
    private var lastPM5Save = Date.distantPast
    let container: ModelContainer
    private let archiveFiles: ArchiveFiles
    private let recoveryDirectory: URL
    private let deleteLegacyCredential: () throws -> Void
    private var dataGeneration = UUID()
    private(set) var isDeletingData = false
    private(set) var isTransferringFiles = false
    private(set) var storageMessage: String?
    private(set) var storageFailed = false

    init(container: ModelContainer, archiveFiles: ArchiveFiles? = nil, deleteLegacyCredential: (() throws -> Void)? = nil) throws {
        self.container = container
        let configuration = container.configurations.first!
        let inMemory = configuration.isStoredInMemoryOnly
        // Test previews and in-memory sessions must never erase the real app's files or credentials.
        let root = inMemory ? FileManager.default.temporaryDirectory.appendingPathComponent("RowivoTesting-" + UUID().uuidString) : configuration.url.deletingLastPathComponent()
        recoveryDirectory = root.appendingPathComponent("RowivoRestoreRecovery", isDirectory: true)
        self.archiveFiles = archiveFiles ?? ArchiveFiles(temporaryDirectory: inMemory ? root : FileManager.default.temporaryDirectory)
        self.deleteLegacyCredential = deleteLegacyCredential ?? (inMemory ? {} : Self.removeLegacyCredential)
        let records = try container.mainContext.fetch(FetchDescriptor<StoredState>())
        if let record = records.first {
            state = try JSONDecoder().decode(AppState.self, from: record.payload)
            guard state.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
        } else { state = AppState() }
        pm5Recording = state.clock == nil ? nil : state.currentPM5Recording
        if pm5Recording != nil { pm5Recording?.breakContinuity(isGap: true) }
        pm5.lockedDeviceID = pm5Recording?.deviceID
        pm5.onSnapshot = { [weak self] snapshot, device in self?.receivePM5(snapshot, device: device) }
        pm5.onInterruption = { [weak self] in
            guard let self, self.pm5Recording != nil else { return }
            self.pm5Recording?.breakContinuity(isGap: true)
            self.flushPM5()
        }
        // Keep legacy payloads readable, but never carry an old AI permission or proposal forward.
        if state.hasAIConsent || state.pendingAdjustment != nil {
            update { $0.hasAIConsent = false; $0.pendingAdjustment = nil }
        }
    }

    var nextWorkout: Workout? { state.plan.flatMap { PlanEngine.next(in: $0, completions: state.completions) } }
    var currentBlock: TrainingBlock? { nextWorkout.flatMap { state.plan?.block(for: $0.id) } }
    var activeWorkout: Workout? { state.plan?.workouts.first { $0.id == state.clock?.workoutID } }
    var latestCompletion: WorkoutCompletion? { state.completions.max { $0.date < $1.date } }
    func recordings(for workoutID: UUID) -> [WorkoutCompletion] {
        state.completions.filter { $0.workoutID == workoutID }.sorted { $0.date > $1.date }
    }
    var canTrain: Bool { PlanEngine.canTrain(completions: state.completions) && !needsCheckIn }
    var needsCheckIn: Bool {
        guard let last = state.completions.max(by: { $0.date < $1.date }) else { return false }
        return last.discomfort && last.id != state.checkedInCompletionID
    }

    @discardableResult func update(_ change: (inout AppState) throws -> Void) -> Bool {
        guard !isDeletingData else { return false }
        do {
            var candidate = state
            try change(&candidate)
            let trainingChanged = candidate.profile != state.profile || candidate.plan != state.plan || candidate.completions != state.completions
            if trainingChanged && candidate.cloudExport?.automaticallyExport == true { candidate.cloudExport?.pending = true }
            let data = try JSONEncoder().encode(candidate)
            let context = container.mainContext
            if let record = try context.fetch(FetchDescriptor<StoredState>()).first {
                record.payload = data; record.updatedAt = Date()
            } else { context.insert(StoredState(payload: data)) }
            try context.save()
            state = candidate
            if trainingChanged && candidate.cloudExport?.automaticallyExport == true {
                Task { [weak self] in await self?.exportIfNeeded() }
            }
            return true
        } catch {
            container.mainContext.rollback()
            errorMessage = message(for: error)
            return false
        }
    }

    @discardableResult func createProfile(_ profile: TrainingProfile, useTemplate: Bool = false) -> Bool {
        update {
            $0.profile = profile
            guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, profile.name.count <= 200,
                  (2...3).contains(profile.sessionsPerWeek), (15...60).contains(profile.sessionMinutes) else { throw PlanError.invalidProfile }
            let plan = useTemplate ? try PlanFactory.make(profile: profile) : TrainingPlan(blocks: [])
            $0.plan = plan
            $0.revisions = [PlanRevision(reason: "Initial plan", plan: plan)]
        }
    }

    func hasRecordings(for id: UUID) -> Bool { state.completions.contains { $0.workoutID == id } }

    @discardableResult private func changePlan(reason: String, baseRevision: Int? = nil, _ edit: (inout TrainingPlan) throws -> Void) -> Bool {
        guard state.clock == nil else { errorMessage = message(for: ManualPlanError.activeWorkout); return false }
        return update { state in
            guard let original = state.plan else { throw ManualPlanError.invalidPlan }
            guard baseRevision == nil || baseRevision == original.revision else { throw ManualPlanError.staleEdit }
            var plan = original
            try edit(&plan)
            guard plan != original else { return }
            guard plan.revision < 1_000_000, state.revisions.count < 1_000 else { throw ManualPlanError.capacity }
            plan.revision += 1
            try ManualPlan.validate(plan)
            // Both full and partial recordings depend on the original workout definition.
            for log in state.completions {
                guard let before = original.workouts.first(where: { $0.id == log.workoutID }),
                      plan.workouts.first(where: { $0.id == log.workoutID }) == before else { throw ManualPlanError.recordedWorkout }
            }
            state.plan = plan; state.pendingAdjustment = nil
            state.revisions.append(.init(reason: reason, plan: plan))
        }
    }

    @discardableResult func saveWorkout(_ workout: Workout, replacing originalID: UUID?, in blockID: UUID?, baseRevision: Int) -> Bool {
        changePlan(reason: originalID == nil ? "Added workout" : "Edited workout", baseRevision: baseRevision) { plan in
            var workout = workout
            let name = workout.customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            workout.customName = name.isEmpty ? nil : name
            try ManualPlan.validateWorkout(workout)
            if let originalID {
                guard workout.id == originalID, !hasRecordings(for: originalID),
                      let originalBlock = plan.blocks.firstIndex(where: { $0.workouts.contains { $0.id == originalID } }),
                      let originalIndex = plan.blocks[originalBlock].workouts.firstIndex(where: { $0.id == originalID }) else { throw ManualPlanError.recordedWorkout }
                if blockID == plan.blocks[originalBlock].id {
                    plan.blocks[originalBlock].workouts[originalIndex] = workout
                    return
                }
                plan.blocks[originalBlock].workouts.remove(at: originalIndex)
            } else if plan.workouts.contains(where: { $0.id == workout.id }) { throw ManualPlanError.invalidPlan }
            if plan.blocks.isEmpty, blockID == nil {
                plan.blocks.append(.init(week: 1, workouts: [workout]))
            } else {
                guard let index = plan.blocks.firstIndex(where: { $0.id == blockID }) else { throw ManualPlanError.staleEdit }
                plan.blocks[index].workouts.append(workout)
            }
        }
    }

    func addBlock() {
        changePlan(reason: "Added block") { plan in
            let number = (plan.blocks.map(\.week).max() ?? 0) + 1
            guard number <= 1_000 else { throw ManualPlanError.capacity }
            plan.blocks.append(.init(week: number, workouts: []))
        }
    }

    func deleteEmptyBlock(_ id: UUID) {
        changePlan(reason: "Removed empty block") { plan in
            guard let index = plan.blocks.firstIndex(where: { $0.id == id }), plan.blocks[index].workouts.isEmpty else { throw ManualPlanError.invalidPlan }
            plan.blocks.remove(at: index)
        }
    }

    func moveBlock(_ id: UUID, by offset: Int) {
        changePlan(reason: "Reordered blocks") { plan in
            guard let index = plan.blocks.firstIndex(where: { $0.id == id }), plan.blocks.indices.contains(index + offset) else { throw ManualPlanError.invalidPlan }
            let block = plan.blocks.remove(at: index); plan.blocks.insert(block, at: index + offset)
        }
    }

    func reorderWorkouts(in blockID: UUID, from offsets: IndexSet, to destination: Int) {
        changePlan(reason: "Reordered workouts") { plan in
            guard let index = plan.blocks.firstIndex(where: { $0.id == blockID }) else { throw ManualPlanError.staleEdit }
            plan.blocks[index].workouts = try ManualPlan.moved(plan.blocks[index].workouts, from: offsets, to: destination)
        }
    }

    @discardableResult func deleteWorkout(_ id: UUID) -> Bool {
        changePlan(reason: "Removed workout") { plan in
            guard let block = plan.blocks.firstIndex(where: { $0.workouts.contains { $0.id == id } }) else { throw ManualPlanError.missingWorkout }
            plan.blocks[block].workouts.removeAll { $0.id == id }
        }
    }

    func start(_ workout: Workout) {
        guard state.clock == nil else { return }
        guard canTrain else { errorMessage = message(for: needsCheckIn ? PlanError.needsCheckIn : PlanError.restDay); return }
        guard nextWorkout?.id == workout.id else { errorMessage = message(for: PlanError.noUpcomingWorkout); return }
        if update({ $0.clock = WorkoutClock(workoutID: workout.id); $0.currentPM5Recording = nil }) {
            pm5Recording = nil; pm5.lockedDeviceID = nil; lastPM5Save = .distantPast
            showingWorkout = true
        }
    }

    func toggleTimer() {
        pm5Recording?.breakContinuity(isGap: false)
        update { state in
            if state.clock?.resumedAt == nil { state.clock?.resume() } else { state.clock?.pause() }
            state.currentPM5Recording = pm5Recording
        }
    }
    func discardTimer() {
        if update({ $0.clock = nil; $0.currentPM5Recording = nil }) {
            showingWorkout = false; pm5Recording = nil; pm5.lockedDeviceID = nil
        }
    }

    func receivePM5(_ snapshot: PM5Snapshot, device: PM5Device) {
        guard !isDeletingData, let clock = state.clock, clock.resumedAt != nil, let workout = activeWorkout else { return }
        let elapsed = clock.elapsed(at: snapshot.date)
        guard elapsed <= Double(workout.totalSeconds) else {
            // The app plan has ended. Never silently attach rowing after its finish.
            if state.clock?.resumedAt != nil { toggleTimer() }
            return
        }
        if pm5Recording == nil {
            pm5Recording = PM5Recording(deviceID: device.id, deviceName: device.name, startsLate: elapsed > 5)
            pm5.lockedDeviceID = device.id
        }
        guard pm5Recording?.deviceID == device.id else { return }
        pm5Recording?.receive(snapshot, workoutElapsed: elapsed)
        if snapshot.date.timeIntervalSince(lastPM5Save) >= 5 { flushPM5() }
    }

    func flushPM5() {
        guard state.clock != nil, pm5Recording != nil else { return }
        if update({ $0.currentPM5Recording = pm5Recording }) { lastPM5Save = Date() }
    }
    func checkIn() { update { $0.checkedInCompletionID = $0.completions.max(by: { $0.date < $1.date })?.id } }

    @discardableResult func deleteAllData() async -> Bool {
        guard !isTransferringFiles, !isDeletingData else {
            errorMessage = String(localized: "Wait for the file operation to finish, then try again.")
            return false
        }
        isDeletingData = true; isTransferringFiles = true
        defer { isDeletingData = false; isTransferringFiles = false }
        do {
            // Hold the file-operation lock across cleanup so restores or exports cannot race a reset.
            try await archiveFiles.deleteLocalCopies(recoveryDirectory: recoveryDirectory)
            try deleteLegacyCredential()
            let context = container.mainContext
            for record in try context.fetch(FetchDescriptor<StoredState>()) { context.delete(record) }
            try context.save()
            state = AppState()
            dataGeneration = UUID()
            showingWorkout = false; pm5Recording = nil; lastPM5Save = .distantPast
            pm5.reset()
            errorMessage = nil; storageMessage = nil; storageFailed = false
            return true
        } catch {
            container.mainContext.rollback()
            errorMessage = String(localized: "Could not delete all local data. Some local copies may already have been removed. Please try again.")
            return false
        }
    }

    private static func removeLegacyCredential() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "app.rowivo.anthropic", kSecAttrAccount as String: "api-key"]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CocoaError(.fileWriteUnknown) }
    }

    func chooseCloudFolder(_ url: URL) async {
        guard !isTransferringFiles else { return }
        isTransferringFiles = true; storageMessage = nil; storageFailed = false
        defer { isTransferringFiles = false }
        do {
            let settings = try await archiveFiles.rememberFolder(url)
            if update({ $0.cloudExport = settings }) { storageMessage = String(localized: "Folder selected. You choose when to export.") }
        } catch { reportStorage(error) }
    }

    func setAutomaticExport(_ enabled: Bool) {
        guard !isTransferringFiles else { return }
        update { $0.cloudExport?.automaticallyExport = enabled }
    }

    func disconnectCloudFolder() {
        guard !isTransferringFiles else { return }
        if update({ $0.cloudExport = nil }) {
            storageFailed = false
            storageMessage = String(localized: "Folder disconnected. Existing copies are kept.")
        }
    }

    func exportIfNeeded() async {
        guard state.cloudExport?.automaticallyExport == true, state.cloudExport?.pending == true,
              state.clock == nil, !isTransferringFiles else { return }
        await exportToFolder()
    }

    func exportToFolder() async {
        guard !isTransferringFiles, state.clock == nil, let settings = state.cloudExport else { return }
        isTransferringFiles = true; storageMessage = nil; storageFailed = false
        defer { isTransferringFiles = false }
        do {
            let archive = try TrainingArchive(state: state)
            let receipt = try await archiveFiles.export(archive, bookmark: settings.bookmark)
            guard state.cloudExport?.id == settings.id else { return }
            if update({ state in
                state.cloudExport?.lastExportAt = receipt.date
                state.cloudExport?.lastSnapshotName = receipt.folderName
                if let bookmark = receipt.refreshedBookmark { state.cloudExport?.bookmark = bookmark }
                state.cloudExport?.pending = state.profile != archive.profile || state.plan != archive.plan || state.completions != archive.completions
            }) {
                storageMessage = String(localized: "Copy handed to your folder. Your provider manages the upload.")
            }
        } catch {
            update { $0.cloudExport?.pending = true }
            reportStorage(error)
        }
    }

    func prepareFileExport() async -> [URL]? {
        guard !isTransferringFiles, state.clock == nil else { return nil }
        isTransferringFiles = true; storageMessage = nil; storageFailed = false
        defer { isTransferringFiles = false }
        do { return try await archiveFiles.prepareExport(TrainingArchive(state: state)) }
        catch { reportStorage(error); return nil }
    }

    func finishFileExport(_ urls: [URL], saved: Bool) async {
        let generation = dataGeneration
        await archiveFiles.removePreparedExport(urls)
        if saved, !isDeletingData, generation == dataGeneration, state.profile != nil {
            storageFailed = false
            storageMessage = String(localized: "Files handed to your provider. Your provider manages the upload.")
        }
    }

    func inspectBackup(_ url: URL) async -> TrainingArchive? {
        guard !isTransferringFiles, state.clock == nil else { return nil }
        isTransferringFiles = true; storageMessage = nil; storageFailed = false
        defer { isTransferringFiles = false }
        do { return try await archiveFiles.readBackup(url) }
        catch { reportStorage(error); return nil }
    }

    func inspectRecovery() async -> TrainingArchive? {
        guard let name = state.restoreRecoveryName, !name.contains("/"), name.hasSuffix(".rowivo") else { return nil }
        return await inspectBackup(recoveryDirectory.appendingPathComponent(name))
    }

    @discardableResult func restoreTraining(_ archive: TrainingArchive) async -> Bool {
        guard !isTransferringFiles, state.clock == nil else { return false }
        isTransferringFiles = true; storageMessage = nil; storageFailed = false
        defer { isTransferringFiles = false }
        do {
            try archive.validate()
            let recovery: String?
            if state.profile != nil {
                recovery = try await archiveFiles.saveRecovery(TrainingArchive(state: state), directory: recoveryDirectory)
            } else { recovery = nil }
            // Recheck after file I/O; starting a workout while the preview was open must not replace it.
            guard state.clock == nil else { throw StorageError.busy }
            guard update({ state in
                state.profile = archive.profile; state.plan = archive.plan
                state.completions = archive.completions; state.revisions = archive.revisions
                state.pendingAdjustment = nil; state.checkedInCompletionID = nil; state.currentPM5Recording = nil
                state.hasAIConsent = false; state.cloudExport = nil; state.restoreRecoveryName = recovery
            }) else { return false }
            pm5Recording = nil; pm5.lockedDeviceID = nil
            storageMessage = String(localized: "Training restored. Cloud copies are off.")
            return true
        } catch { reportStorage(error); return false }
    }

    private func reportStorage(_ error: any Error) {
        storageFailed = true
        switch error {
        case StorageError.noTraining: storageMessage = String(localized: "Create or restore a training plan first.")
        case StorageError.invalidBackup: storageMessage = String(localized: "This is not a valid Rowivo training backup. Your training has not changed.")
        case StorageError.newerBackup: storageMessage = String(localized: "This backup needs a newer version of Rowivo. Your training has not changed.")
        case StorageError.tooLarge: storageMessage = String(localized: "This backup exceeds the 64 MB import limit. Your training has not changed.")
        case StorageError.busy: storageMessage = String(localized: "Finish your active session before exporting or restoring training.")
        default: storageMessage = String(localized: "Could not access your files. Check your provider or choose the folder again. Your local training is safe.")
        }
    }

    @discardableResult func updateCompletionDate(_ original: WorkoutCompletion, to date: Date) -> Bool {
        var edit = RecordedWorkoutEdit(original)
        edit.date = date
        return updateCompletion(original, with: edit)
    }

    @discardableResult func updateCompletion(_ original: WorkoutCompletion, with edit: RecordedWorkoutEdit) -> Bool {
        guard state.clock == nil else { errorMessage = message(for: RecordedWorkoutEditError.activeWorkout); return false }
        return update { state in
            try edit.validate()
            guard let index = state.completions.firstIndex(where: { $0.id == original.id }),
                  state.completions[index] == original,
                  let workout = state.plan?.workouts.first(where: { $0.id == original.workoutID }) else { throw RecordedWorkoutEditError.staleEntry }
            var corrected = original
            let name = edit.name.trimmingCharacters(in: .whitespacesAndNewlines)
            corrected.customName = name.isEmpty ? nil : name
            corrected.title = edit.kind; corrected.date = edit.date
            corrected.durationSeconds = edit.durationSeconds; corrected.effort = edit.effort
            corrected.discomfort = edit.discomfort; corrected.note = edit.note
            corrected.finishedPlan = edit.durationSeconds >= workout.totalSeconds
            guard corrected != original else { return }
            corrected.recordedAt = original.recordedAt ?? original.date
            corrected.editedAt = Date()
            state.completions[index] = corrected
            if corrected.discomfort != original.discomfort, state.checkedInCompletionID == original.id {
                state.checkedInCompletionID = nil
            }
            state.pendingAdjustment = nil
        }
    }

    @discardableResult func complete(_ workout: Workout, seconds: Int, effort: Int, discomfort: Bool, note: String, manual: Bool, trainedAt: Date? = nil) -> Bool {
        guard nextWorkout == workout else { errorMessage = message(for: ManualPlanError.staleEdit); return false }
        // Logging an already completed workout does not authorize starting a new one.
        guard manual || canTrain else { errorMessage = message(for: PlanError.restDay); return false }
        guard seconds > 0, seconds <= 4 * 3600, (1...5).contains(effort) else { errorMessage = message(for: PlanError.invalidWorkout); return false }
        guard !manual || state.clock == nil else { errorMessage = message(for: PlanError.invalidWorkout); return false }
        let recordedAt = Date()
        let trainingDate = trainedAt ?? recordedAt
        guard (manual || trainedAt == nil), trainingDate.timeIntervalSinceReferenceDate.isFinite, trainingDate <= recordedAt else {
            errorMessage = message(for: PlanError.invalidTrainingDate); return false
        }
        let saved = update { state in
            state.completions.append(.init(workout: workout, date: trainingDate, durationSeconds: seconds, effort: effort, discomfort: discomfort,
                                           note: String(note.prefix(2000)), manuallyRecorded: manual,
                                           pm5: !manual && pm5Recording?.hasMeasurements == true ? pm5Recording : nil, recordedAt: recordedAt))
            state.clock = nil; state.pendingAdjustment = nil; state.currentPM5Recording = nil
        }
        if saved { showingWorkout = false; pm5Recording = nil; pm5.lockedDeviceID = nil }
        return saved
    }

    func message(for error: Error) -> String {
        switch error {
        case RecordedWorkoutEditError.activeWorkout: String(localized: "Finish your active session before editing recorded workouts.")
        case RecordedWorkoutEditError.staleEntry: String(localized: "This entry has changed. Close and reopen it to try again.")
        case RecordedWorkoutEditError.invalidDuration: String(localized: "Enter a duration between 1 second and 4 hours.")
        case RecordedWorkoutEditError.invalidEffort: String(localized: "Choose an effort between 1 and 5.")
        case RecordedWorkoutEditError.noteTooLong: String(localized: "Keep notes within 20,000 characters.")
        case PlanError.restDay: String(localized: "Give yourself a rest day between sessions.")
        case PlanError.needsCheckIn: String(localized: "Check in about your discomfort before starting again.")
        case PlanError.invalidTrainingDate: String(localized: "Choose a valid workout date that is not in the future.")
        case PlanError.staleProposal: String(localized: "The plan has changed. Reopen the editor and try again.")
        case PlanError.duplicateCompletion: String(localized: "This session has already been recorded.")
        case PlanError.noCompletedBlock: String(localized: "Complete a training block before repeating it.")
        case PlanError.invalidAdjustment: String(localized: "This change does not fit your training plan.")
        case is PlanError: String(localized: "Please check your training details and try again.")
        case ManualPlanError.activeWorkout: String(localized: "Finish the active workout before editing your plan.")
        case ManualPlanError.recordedWorkout: String(localized: "This workout has recordings. Duplicate it to make changes.")
        case ManualPlanError.staleEdit: String(localized: "The plan has changed. Reopen the editor and try again.")
        case ManualPlanError.noRowing: String(localized: "Add at least one rowing step.")
        case ManualPlanError.invalidDuration: String(localized: "Each step must last between 1 second and 60 minutes.")
        case ManualPlanError.tooLong: String(localized: "Keep the total workout within four hours.")
        case ManualPlanError.tooManySteps: String(localized: "A workout can contain up to 100 steps.")
        case ManualPlanError.nameTooLong: String(localized: "Keep the workout name within 80 characters.")
        case is ManualPlanError: String(localized: "Could not update this plan. Check the workout and try again.")
        default: String(localized: "Your changes could not be saved. Please try again.")
        }
    }
}
