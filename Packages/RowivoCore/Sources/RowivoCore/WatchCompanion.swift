import Foundation

/// Only the current workout and monitor values cross devices, never the full profile or history.
public struct WatchSnapshot: Codable, Equatable, Sendable {
    public var version = 1
    public var generatedAt: Date
    public var controlToken: UUID
    public var availability: WatchAvailability
    public var workout: Workout?
    public var clock: WorkoutClock?
    public var metrics: WatchMetrics?
    public var availableAt: Date?
    public var lastSavedWorkoutID: UUID?
    public var lastSavedAt: Date?

    public init(controlToken: UUID, availability: WatchAvailability, workout: Workout? = nil,
                clock: WorkoutClock? = nil, metrics: WatchMetrics? = nil, availableAt: Date? = nil,
                generatedAt: Date = Date()) {
        self.controlToken = controlToken; self.availability = availability; self.workout = workout
        self.clock = clock; self.metrics = metrics; self.availableAt = availableAt; self.generatedAt = generatedAt
    }

    public func elapsed(at date: Date) -> Int {
        guard let workout, let clock else { return 0 }
        return Int(min(Double(workout.totalSeconds), max(0, clock.elapsed(at: date))))
    }

    public func validate() throws {
        guard version == 1, generatedAt.timeIntervalSinceReferenceDate.isFinite else { throw WatchWireError.invalidPayload }
        if let workout { try ManualPlan.validateWorkout(workout) }
        if let clock {
            guard clock.workoutID == workout?.id, clock.accumulated.isFinite,
                  clock.accumulated >= 0, clock.accumulated <= 604_800,
                  clock.resumedAt?.timeIntervalSinceReferenceDate.isFinite != false else { throw WatchWireError.invalidPayload }
        }
        if let metrics {
            guard metrics.date.timeIntervalSinceReferenceDate.isFinite,
                  metrics.distance.map({ $0.isFinite && $0 >= 0 }) ?? true,
                  metrics.pace.map({ $0.isFinite && (0.01...65535).contains($0) }) != false else { throw WatchWireError.invalidPayload }
        }
    }
}

public enum WatchAvailability: String, Codable, Sendable {
    case ready, noProfile, noPlan, restDay, checkIn, busy
}

public struct WatchMetrics: Codable, Equatable, Sendable {
    public var date: Date
    public var distance: Double?
    public var pace: Double?
    public var strokeRate: Double?
    public var watts: Int?
    public var heartRate: Int?
    public init(snapshot: PM5Snapshot, distance: Double) {
        self.init(snapshot: RowerSnapshot(snapshot), distance: distance)
    }
    public init(snapshot: RowerSnapshot, distance: Double?) {
        date = snapshot.date; self.distance = distance; pace = snapshot.pace
        strokeRate = snapshot.strokeRate; watts = snapshot.watts; heartRate = snapshot.heartRate
    }
    public func isFresh(at date: Date) -> Bool { (0...5).contains(date.timeIntervalSince(self.date)) }
}

public struct WatchCommand: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable { case refresh, start, pause, resume, save, discard }
    public var version = 1
    public var id = UUID()
    public var issuedAt: Date
    public var action: Action
    public var controlToken: UUID?
    public var workoutID: UUID?
    public var effort: Int?
    public var discomfort: Bool?
    public var note: String?
    public var acknowledgesRecentTraining: Bool?
    public init(action: Action, snapshot: WatchSnapshot? = nil, effort: Int? = nil,
                discomfort: Bool? = nil, note: String? = nil, acknowledgingRecentTraining: Bool = false, issuedAt: Date = Date()) {
        self.action = action; controlToken = snapshot?.controlToken; workoutID = snapshot?.workout?.id
        self.effort = effort; self.discomfort = discomfort; self.note = note; self.issuedAt = issuedAt
        acknowledgesRecentTraining = acknowledgingRecentTraining ? true : nil
    }
}

public enum WatchCommandResult: String, Codable, Sendable { case ok, stale, unavailable, invalid, failed }
public struct WatchReply: Codable, Sendable {
    public var requestID: UUID
    public var result: WatchCommandResult
    public var snapshot: WatchSnapshot
    public init(requestID: UUID, result: WatchCommandResult, snapshot: WatchSnapshot) {
        self.requestID = requestID; self.result = result; self.snapshot = snapshot
    }
}

public enum WatchWireError: Error { case invalidPayload, tooLarge }
public enum WatchWire {
    public static let contextKey = "rowivo.snapshot.v1"
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let data = try JSONEncoder().encode(value)
        guard data.count <= 60_000 else { throw WatchWireError.tooLarge }
        return data
    }
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard data.count <= 60_000 else { throw WatchWireError.tooLarge }
        return try JSONDecoder().decode(type, from: data)
    }
}
