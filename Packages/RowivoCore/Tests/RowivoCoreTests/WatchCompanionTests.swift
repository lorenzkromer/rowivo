import XCTest
@testable import RowivoCore

final class WatchCompanionTests: XCTestCase {
    func testSnapshotRoundTripAndPausedClock() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let workout = Workout(kind: .intervals, segments: [.init(kind: .work, seconds: 60), .init(kind: .rest, seconds: 30)])
        var clock = WorkoutClock(workoutID: workout.id, now: date)
        var snapshot = WatchSnapshot(controlToken: UUID(), availability: .ready, workout: workout, clock: clock, generatedAt: date)
        try snapshot.validate()
        XCTAssertEqual(snapshot.elapsed(at: date.addingTimeInterval(70)), 70)
        XCTAssertEqual(snapshot.elapsed(at: date.addingTimeInterval(120)), 90)
        clock.pause(at: date.addingTimeInterval(20)); snapshot.clock = clock
        XCTAssertEqual(snapshot.elapsed(at: date.addingTimeInterval(80)), 20)
        let restored = try WatchWire.decode(WatchSnapshot.self, from: WatchWire.encode(snapshot))
        XCTAssertEqual(restored, snapshot)
    }
    func testRejectsUnsupportedOversizedAndInvalidSnapshots() throws {
        var snapshot = WatchSnapshot(controlToken: UUID(), availability: .noProfile)
        snapshot.version = 2
        XCTAssertThrowsError(try snapshot.validate())
        snapshot.version = 1; snapshot.clock = WorkoutClock(workoutID: UUID())
        XCTAssertThrowsError(try snapshot.validate())
        XCTAssertThrowsError(try WatchWire.encode(String(repeating: "x", count: 60_001)))
        XCTAssertThrowsError(try WatchWire.decode(WatchSnapshot.self, from: Data(repeating: 32, count: 60_001)))
    }
    func testMonitorFreshnessAndCommandIdentity() throws {
        let date = Date()
        let metrics = WatchMetrics(snapshot: .init(date: date, general: .init(elapsed: 10, distance: 40), pace: 130, strokeRate: 23), distance: 30)
        XCTAssertTrue(metrics.isFresh(at: date.addingTimeInterval(4)))
        XCTAssertFalse(metrics.isFresh(at: date.addingTimeInterval(6)))
        XCTAssertFalse(metrics.isFresh(at: date.addingTimeInterval(-1)))
        let snapshot = WatchSnapshot(controlToken: UUID(), availability: .ready, metrics: metrics)
        let command = WatchCommand(action: .pause, snapshot: snapshot)
        XCTAssertEqual(try WatchWire.decode(WatchCommand.self, from: WatchWire.encode(command)), command)
        XCTAssertEqual(command.controlToken, snapshot.controlToken)
    }
}
