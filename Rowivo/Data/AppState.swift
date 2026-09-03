import Foundation
import RowivoCore
import SwiftData

struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    enum Role: String, Codable, Sendable { case user, assistant }
    var id = UUID()
    var role: Role
    var text: String
    var date = Date()
    var failed = false
}

struct PlanRevision: Codable, Identifiable, Sendable {
    var id = UUID()
    var date = Date()
    var reason: String
    var plan: TrainingPlan
}

struct AppState: Codable, Sendable {
    var schemaVersion = 1
    var profile: TrainingProfile?
    var plan: TrainingPlan?
    var completions: [WorkoutCompletion] = []
    // Legacy fields stay decodable so removing the coach does not erase old local payloads.
    var messages: [ChatMessage] = []
    var revisions: [PlanRevision] = []
    var pendingAdjustment: PendingAdjustment?
    var clock: WorkoutClock?
    var currentPM5Recording: PM5Recording?
    var hasAIConsent = false
    var checkedInCompletionID: UUID?
    var modelID = "claude-sonnet-4-6"
    var cloudExport: CloudExportSettings?
    var restoreRecoveryName: String?
}

struct CloudExportSettings: Codable, Sendable {
    var id = UUID()
    var bookmark: Data
    var folderName: String
    var automaticallyExport = false
    var pending = false
    var lastExportAt: Date?
    var lastSnapshotName: String?
}

@Model final class StoredState {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date
    init(payload: Data) { key = "primary"; self.payload = payload; updatedAt = Date() }
}
