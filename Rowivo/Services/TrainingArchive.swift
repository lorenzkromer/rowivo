import Foundation
import RowivoCore

enum StorageError: Error, Equatable { case noTraining, invalidBackup, newerBackup, tooLarge, inaccessibleFolder, busy }

/// Training only. Credentials, chat, sharing consent, bookmarks and in-flight state
/// never enter the portable backup or the cloud copy.
struct TrainingArchive: Codable, Sendable {
    static let currentVersion = 5
    var format = "app.rowivo.training"
    var version = Self.currentVersion
    var createdAt: Date
    var profile: TrainingProfile
    var plan: TrainingPlan
    var completions: [WorkoutCompletion]
    var revisions: [PlanRevision]

    init(state: AppState, at date: Date = Date()) throws {
        guard let profile = state.profile, let plan = state.plan else { throw StorageError.noTraining }
        createdAt = date; self.profile = profile; self.plan = plan
        completions = state.completions; revisions = state.revisions
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= 64 * 1024 * 1024 else { throw StorageError.tooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 64 * 1024 * 1024 else { throw StorageError.tooLarge }
        // Inspect the format header before decoding a potentially different future schema.
        struct Header: Decodable { var format: String; var version: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data), header.format == "app.rowivo.training" else { throw StorageError.invalidBackup }
        guard header.version <= currentVersion else { throw StorageError.newerBackup }
        guard (1...currentVersion).contains(header.version), let archive = try? JSONDecoder().decode(Self.self, from: data) else { throw StorageError.invalidBackup }
        try archive.validate()
        return archive
    }

    func validate() throws {
        guard format == "app.rowivo.training", (1...Self.currentVersion).contains(version) else { throw StorageError.invalidBackup }
        guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, profile.name.count <= 200,
              (2...3).contains(profile.sessionsPerWeek), (15...60).contains(profile.sessionMinutes),
              completions.count <= 10_000, revisions.count <= 1_000,
              Set(completions.map(\.id)).count == completions.count else { throw StorageError.invalidBackup }
        func validatePlan(_ plan: TrainingPlan) throws {
            do {
                try ManualPlan.validate(plan)
                if version == 1 {
                    guard !plan.blocks.isEmpty, plan.blocks.allSatisfy({ (1...3).contains($0.workouts.count) }) else { throw StorageError.invalidBackup }
                    try PlanFactory.validate(plan, maximumMinutes: 60)
                }
            } catch { throw StorageError.invalidBackup }
        }
        try validatePlan(plan)
        for revision in revisions { try validatePlan(revision.plan) }
        let workouts = Dictionary(uniqueKeysWithValues: plan.workouts.map { ($0.id, $0) })
        var finished: Set<UUID> = []
        var totalSamples = 0
        for log in completions {
            guard let workout = workouts[log.workoutID], (1...14_400).contains(log.durationSeconds),
                  log.date.timeIntervalSinceReferenceDate.isFinite,
                  // A corrected workout date can be later than the original capture date.
                  log.recordedAt.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true,
                  log.editedAt.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true,
                  (1...5).contains(log.effort), log.note.count <= 20_000,
                  log.customName.map({ $0.count <= 80 }) ?? true,
                  log.finishedPlan == (log.durationSeconds >= workout.totalSeconds),
                  // Corrections can turn several distinct partial sessions into full ones.
                  // Their session IDs remain unique; the plan counts the workout only once.
                  version >= 4 || !log.finishedPlan || finished.insert(log.workoutID).inserted else { throw StorageError.invalidBackup }
            if let recording = log.pm5 {
                totalSamples += recording.samples.count
                guard !log.manuallyRecorded, recording.samples.count <= 14_500, totalSamples <= 500_000,
                      recording.distance.isFinite, recording.distance >= 0, recording.distance <= 500_000,
                      recording.rowingSeconds.isFinite, (0...14_400).contains(recording.rowingSeconds), recording.segment >= 0 else { throw StorageError.invalidBackup }
                var previousDate = Date.distantPast
                var previousDistance = 0.0
                for (index, sample) in recording.samples.enumerated() {
                    guard sample.id == index, sample.date >= previousDate,
                          sample.workoutElapsed.isFinite, (0...14_401).contains(sample.workoutElapsed),
                          sample.monitorElapsed.map({ $0.isFinite && $0 >= 0 }) ?? true,
                          sample.monitorDistance.map({ $0.isFinite && $0 >= 0 }) ?? true,
                          sample.recordedDistance.isFinite, sample.recordedDistance >= previousDistance,
                          sample.recordedDistance <= recording.distance + 0.001,
                          sample.strokeCount.map({ (0...65535).contains($0) }) ?? true,
                          sample.segment >= 0, sample.segment <= recording.segment,
                          sample.pace.map({ $0.isFinite && $0 > 0 && $0 <= (recording.deviceProtocol == .ftms ? 65535 : 655.35) }) ?? true,
                          sample.strokeRate.map({ $0.isFinite && (0...255).contains($0) }) ?? true,
                          sample.watts.map({ (recording.deviceProtocol == .ftms ? -32768...32767 : 0...65535).contains($0) }) ?? true,
                          sample.heartRate.map({ (1...255).contains($0) }) ?? true else { throw StorageError.invalidBackup }
                    previousDate = sample.date; previousDistance = sample.recordedDistance
                }
            }
        }
    }

    func exportFiles() throws -> [String: Data] {
        try validate()
        let date = ISO8601DateFormatter()
        date.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func decimal(_ value: Double?) -> CSVValue { value.map(CSVValue.number) ?? .empty }
        func integer(_ value: Int?) -> CSVValue { value.map(CSVValue.integer) ?? .empty }
        var profileCSV = CSVTable(headers: ["schema_version", "name", "goal", "experience", "sessions_per_block", "session_budget_minutes"])
        profileCSV.append([.integer(Self.currentVersion), .text(profile.name), .text(profile.goal.rawValue), .text(profile.experience.rawValue), .integer(profile.sessionsPerWeek), .integer(profile.sessionMinutes)])
        var sessions = CSVTable(headers: ["schema_version", "session_id", "workout_id", "recorded_at_utc", "workout_type", "duration_seconds", "effort_1_5", "discomfort", "note", "manual", "finished_plan", "source", "device_name", "device_distance_m", "device_elapsed_seconds", "device_average_pace_seconds_per_500m", "device_has_gaps", "workout_name", "trained_at_utc", "edited_at_utc"])
        var samples = CSVTable(headers: ["schema_version", "session_id", "sample_index", "timestamp_utc", "app_elapsed_seconds", "device_elapsed_seconds", "monitor_distance_m", "recorded_distance_m", "pace_seconds_per_500m", "stroke_rate_spm", "power_w", "heart_rate_bpm", "segment", "stroke_count"])
        for log in completions.sorted(by: { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }) {
            sessions.append([.integer(Self.currentVersion), .text(log.id.uuidString), .text(log.workoutID.uuidString), .text(date.string(from: log.recordedAt ?? log.date)),
                             .text(log.title.rawValue), .integer(log.durationSeconds), .integer(log.effort), .boolean(log.discomfort),
                             .text(log.note), .boolean(log.manuallyRecorded), .boolean(log.finishedPlan),
                             .text(log.pm5?.deviceProtocol.rawValue ?? (log.manuallyRecorded ? "manual" : "app_timer")),
                             log.pm5.map { .text($0.deviceName) } ?? .empty, decimal(log.pm5?.measuredDistance), decimal(log.pm5?.measuredTime),
                             decimal(log.pm5?.averagePace), log.pm5.map { .boolean($0.hasGaps) } ?? .empty, log.customName.map(CSVValue.text) ?? .empty,
                             .text(date.string(from: log.date)), log.editedAt.map { .text(date.string(from: $0)) } ?? .empty])
            for sample in log.pm5?.samples ?? [] {
                samples.append([.integer(Self.currentVersion), .text(log.id.uuidString), .integer(sample.id), .text(date.string(from: sample.date)),
                                .number(sample.workoutElapsed), decimal(sample.monitorElapsed), decimal(sample.monitorDistance),
                                sample.monitorDistance == nil ? .empty : .number(sample.recordedDistance), decimal(sample.pace), decimal(sample.strokeRate), integer(sample.watts),
                                integer(sample.heartRate), .integer(sample.segment), integer(sample.strokeCount)])
            }
        }
        var planCSV = CSVTable(headers: ["schema_version", "plan_revision", "block_id", "week", "repeated_block", "workout_id", "workout_type", "segment_index", "segment_type", "intensity", "duration_seconds", "workout_name"])
        for block in plan.blocks {
            for workout in block.workouts {
                for (index, segment) in workout.segments.enumerated() {
                    planCSV.append([.integer(Self.currentVersion), .integer(plan.revision), .text(block.id.uuidString), .integer(block.week), .boolean(block.isRepeat),
                                    .text(workout.id.uuidString), .text(workout.kind.rawValue), .integer(index), .text(segment.kind.rawValue),
                                    .text(segment.intensity.rawValue), .integer(segment.seconds), workout.customName.map(CSVValue.text) ?? .empty])
                }
            }
        }
        return ["profile.csv": profileCSV.data, "sessions.csv": sessions.data, "rower_samples.csv": samples.data, "plan.csv": planCSV.data,
                "training.rowivo": try encoded(), "README.txt": Data(Self.readme.utf8)]
    }

    static let readme = """
    ROWIVO TRAINING EXPORT — FORMAT 5
    Each export is an independent snapshot. Previous copies are never overwritten.
    profile.csv: training preferences. plan.csv: current plan, one row per segment.
    sessions.csv: saved sessions, one row per session. recorded_at_utc is the save date.
    trained_at_utc is the workout date, chosen by you for manual entries. Older entries
    use their original save date as the workout date; no historical date is inferred.
    rower_samples.csv: received device measurements, joined to sessions.csv by session_id.
    source identifies pm5, ftms, manual or app_timer. Device fields are empty when unavailable.
    Format 5 renames pm5_* headers to device_* and pm5_samples.csv to rower_samples.csv.
    PM5 backups from formats 1–4 remain readable. Older app versions cannot import format 5.
    workout_name preserves optional custom names in plan.csv and sessions.csv.
    Session details can be corrected without changing the original plan or device samples.
    edited_at_utc is the last manual correction; empty means no correction is recorded.
    finished_plan follows the corrected duration. Multiple sessions may fulfill the same workout.
    CSV uses UTF-8 with BOM, comma separators, quoted fields, CRLF, decimal points,
    UTC ISO-8601 dates, stable English headers and empty fields for missing values.
    Indices start at zero. Units are in column names. No missing data is estimated.
    Formula-like user text is prefixed with an apostrophe for spreadsheet safety.
    training.rowivo: versioned JSON backup for restoration in Rowivo. Original text
    and training plan revisions are preserved here. Do not edit it for spreadsheet use.
    Cloud access and unfinished sessions are NOT included. Legacy chat and credentials are excluded.
    Select training.rowivo in Rowivo to preview and restore the training snapshot.
    This is a file export, not two-way sync or a shared writable database.
    Your chosen provider manages uploads. A local write does not confirm server upload.

    DEUTSCH
    Jede Kopie ist ein eigener Stand. Frühere Kopien werden nicht überschrieben.
    CSV-Dateien sind für die Auswertung; training.rowivo ist für die Wiederherstellung.
    trained_at_utc enthält das Trainingsdatum, recorded_at_utc den Erfassungszeitpunkt.
    Bei älteren Einträgen wird das bisher gespeicherte Datum für beide verwendet.
    Chat, API-Schlüssel, Freigaben und laufende Einheiten sind nicht enthalten.
    Der gewählte Speicheranbieter übernimmt das Hochladen.
    """
}
