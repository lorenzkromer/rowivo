import Foundation

/// Debounces actual device readings, never missing packets. Planned rests keep counting.
public struct PowerPauseDetector: Sendable {
    public enum Action: Equatable, Sendable { case pause, resume }
    private var since: Date?
    private var previous: Date?
    private var wasPaused = false
    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func receive(watts: Int?, at date: Date, threshold: Int, running: Bool,
                                 automaticallyPaused: Bool, resting: Bool) -> Action? {
        if let previous, date <= previous { return nil }
        defer { previous = date; wasPaused = automaticallyPaused }
        guard let watts, watts >= 0, !resting, running || automaticallyPaused else { since = nil; return nil }
        if previous.map({ date.timeIntervalSince($0) > 4 }) == true || wasPaused != automaticallyPaused { since = nil }
        let qualifies = automaticallyPaused ? watts >= threshold + 4 : watts < threshold
        guard qualifies else { since = nil; return nil }
        if since == nil { since = date }
        guard date.timeIntervalSince(since!) >= (automaticallyPaused ? 2 : 6) else { return nil }
        since = nil
        return automaticallyPaused ? .resume : .pause
    }
}
