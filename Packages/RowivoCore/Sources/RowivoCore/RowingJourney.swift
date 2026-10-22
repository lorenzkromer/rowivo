import Foundation

/// A journey is a projection of saved measurements. No second distance ledger can drift
/// from history, and backups/imports retain the same progress without a new schema.
public struct RowingJourney: Equatable, Sendable {
    public struct Stop: Equatable, Sendable, Identifiable {
        public let id: Int
        public let name: String
        public let meters: Double
    }
    public static let stops: [Stop] = [
        .init(id: 0, name: "Morning lake", meters: 0),
        .init(id: 1, name: "Reed bay", meters: 1_000),
        .init(id: 2, name: "Forest landing", meters: 3_500),
        .init(id: 3, name: "Island clearing", meters: 8_500)
    ]
    public let meters: Double
    public init(meters: Double) { self.meters = meters.isFinite ? max(0, meters) : 0 }
    public init(completions: [WorkoutCompletion]) {
        var seen = Set<UUID>()
        self.init(meters: completions.reduce(0) { total, log in
            guard seen.insert(log.id).inserted, !log.manuallyRecorded,
                  let distance = log.pm5?.measuredDistance, distance.isFinite, distance > 0 else { return total }
            return total + distance
        })
    }
    public var discovered: [Stop] { Self.stops.filter { $0.meters <= meters } }
    public var next: Stop? { Self.stops.first { $0.meters > meters } }
    public var current: Stop { discovered.last ?? Self.stops[0] }
    public var remaining: Double { max(0, (next?.meters ?? meters) - meters) }
    public var legProgress: Double {
        guard let next else { return 1 }
        return min(1, max(0, (meters - current.meters) / (next.meters - current.meters)))
    }
    public func adding(_ distance: Double?) -> Self {
        guard let distance, distance.isFinite, distance > 0 else { return self }
        return Self(meters: meters + distance)
    }
}
