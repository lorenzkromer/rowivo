import Foundation

public enum RowerProtocol: String, Codable, Sendable {
    case concept2 = "pm5", ftms
}

/// Common measurements. Missing device counters remain absent; the app timer is separate.
public struct RowerSnapshot: Equatable, Sendable {
    public var date: Date
    public var elapsed: Double?
    public var distance: Double?
    public var pace: Double?
    public var strokeRate: Double?
    public var strokeCount: Int?
    public var watts: Int?
    public var heartRate: Int?
    public var workoutType: UInt8?

    public init(date: Date, elapsed: Double? = nil, distance: Double? = nil, pace: Double? = nil,
                strokeRate: Double? = nil, strokeCount: Int? = nil, watts: Int? = nil,
                heartRate: Int? = nil, workoutType: UInt8? = nil) {
        self.date = date; self.elapsed = elapsed; self.distance = distance; self.pace = pace
        self.strokeRate = strokeRate; self.strokeCount = strokeCount; self.watts = watts
        self.heartRate = heartRate; self.workoutType = workoutType
    }

    public init(_ snapshot: PM5Snapshot) {
        self.init(date: snapshot.date, elapsed: snapshot.general.elapsed, distance: snapshot.general.distance,
                  pace: snapshot.pace, strokeRate: snapshot.strokeRate.map(Double.init), watts: snapshot.watts,
                  heartRate: snapshot.heartRate, workoutType: snapshot.general.workoutType)
    }
}

public struct RowerSample: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var date: Date
    public var workoutElapsed: Double
    public var monitorElapsed: Double?
    public var monitorDistance: Double?
    public var recordedDistance: Double
    public var pace: Double?
    public var strokeRate: Double?
    public var watts: Int?
    public var heartRate: Int?
    public var segment: Int
    public var strokeCount: Int?
}

public struct RowerRecording: Codable, Equatable, Sendable {
    public var deviceID: UUID
    public var deviceName: String
    private var protocolKind: RowerProtocol?
    public var deviceProtocol: RowerProtocol { protocolKind ?? .concept2 }
    public private(set) var samples: [RowerSample] = []
    public private(set) var distance: Double = 0
    public private(set) var rowingSeconds: Double = 0
    public private(set) var hasGaps = false
    public private(set) var segment = 0
    // A baseline is deliberately NOT persisted: reconnect/relaunch must establish a new one.
    private var baseline: RowerSnapshot?
    private var lastStoredDate: Date?
    private var incompleteCounters: Bool?
    private enum CodingKeys: String, CodingKey { case deviceID, deviceName, samples, distance, rowingSeconds, hasGaps, segment, protocolKind, incompleteCounters }

    public init(deviceID: UUID, deviceName: String, startsLate: Bool = false, deviceProtocol: RowerProtocol = .concept2) {
        self.deviceID = deviceID; self.deviceName = deviceName; hasGaps = startsLate; protocolKind = deviceProtocol == .concept2 ? nil : deviceProtocol
    }
    public var measuredDistance: Double? { samples.contains { $0.monitorDistance != nil } ? distance : nil }
    public var measuredTime: Double? { samples.contains { $0.monitorElapsed != nil } ? rowingSeconds : nil }
    public var averagePace: Double? {
        guard distance > 0, rowingSeconds > 0, incompleteCounters != true,
              samples.allSatisfy({ $0.monitorElapsed != nil && $0.monitorDistance != nil }) else { return nil }
        return rowingSeconds / distance * 500
    }
    public var hasMeasurements: Bool { !samples.isEmpty }

    public mutating func breakContinuity(isGap: Bool) {
        baseline = nil; lastStoredDate = nil; segment += 1
        if isGap { hasGaps = true }
    }

    /// Only consecutive observations during the active app timer contribute to totals.
    /// Missing spans and reset counters are excluded, rather than extrapolated.
    public mutating func receive(_ snapshot: PM5Snapshot, workoutElapsed: Double) {
        receive(RowerSnapshot(snapshot), workoutElapsed: workoutElapsed)
    }

    public mutating func receive(_ snapshot: RowerSnapshot, workoutElapsed: Double) {
        guard samples.count < 14_500 else { hasGaps = true; baseline = nil; return }
        if let baseline, snapshot.date <= baseline.date { return }
        defer { baseline = snapshot }
        if snapshot.elapsed == nil || snapshot.distance == nil { incompleteCounters = true }
        if let old = baseline {
            let wall = snapshot.date.timeIntervalSince(old.date)
            let dt = snapshot.elapsed.flatMap { value in old.elapsed.map { value - $0 } }
            let dm = snapshot.distance.flatMap { value in old.distance.map { value - $0 } }
            let strokeReset = snapshot.strokeCount.flatMap { value in old.strokeCount.map { value < $0 } } ?? false
            if wall <= 5, dt.map({ $0 >= 0 && $0 <= wall + 2 }) ?? true,
               dm.map({ $0 >= 0 && $0 <= (wall + 2) * 15 }) ?? true,
               snapshot.workoutType == old.workoutType, !strokeReset {
                if let dm { distance += dm }
                if let dt { rowingSeconds += dt }
                if (snapshot.distance == nil) != (old.distance == nil) ||
                   (snapshot.elapsed == nil) != (old.elapsed == nil) { hasGaps = true }
            } else { breakContinuity(isGap: true) }
        }
        // Up to one persisted sample/second; counters still account for every notification.
        if let lastStoredDate, snapshot.date.timeIntervalSince(lastStoredDate) < 1 { return }
        samples.append(.init(id: samples.count, date: snapshot.date, workoutElapsed: workoutElapsed,
                             monitorElapsed: snapshot.elapsed, monitorDistance: snapshot.distance,
                             recordedDistance: distance, pace: snapshot.pace, strokeRate: snapshot.strokeRate,
                             watts: snapshot.watts, heartRate: snapshot.heartRate, segment: segment, strokeCount: snapshot.strokeCount))
        lastStoredDate = snapshot.date
    }
}

// Source compatibility; serialized pm5/currentPM5Recording keys remain stable for existing data.
public typealias PM5Recording = RowerRecording
public typealias PM5Sample = RowerSample
