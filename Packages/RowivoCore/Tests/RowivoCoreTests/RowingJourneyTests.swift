import XCTest
@testable import RowivoCore

final class RowingJourneyTests: XCTestCase {
    func testStopsBoundariesAndOverflow() {
        XCTAssertEqual(RowingJourney(meters: 0).discovered.count, 1)
        XCTAssertEqual(RowingJourney(meters: 500).legProgress, 0.5)
        let bay = RowingJourney(meters: 1_000)
        XCTAssertEqual(bay.current.name, "Reed bay")
        XCTAssertEqual(bay.remaining, 2_500)
        XCTAssertEqual(bay.legProgress, 0)
        let finished = RowingJourney(meters: 12_000)
        XCTAssertNil(finished.next)
        XCTAssertEqual(finished.legProgress, 1)
        XCTAssertEqual(finished.meters, 12_000)
        XCTAssertEqual(finished.discovered.count, 4)
    }
    func testInvalidMeasurementsAndPreview() {
        for value in [Double.nan, .infinity, -.infinity, -10] {
            XCTAssertEqual(RowingJourney(meters: value).meters, 0)
            XCTAssertEqual(RowingJourney(meters: 400).adding(value).meters, 400)
        }
        XCTAssertEqual(RowingJourney(meters: 400).adding(nil).meters, 400)
        XCTAssertEqual(RowingJourney(meters: 400).adding(500).meters, 900)
    }
    func testSavedPartialUnitsDeduplicateAndDeletionRecalculates() throws {
        let workout = Workout(kind: .endurance, segments: [.init(kind: .work, seconds: 600)])
        var recording = RowerRecording(deviceID: UUID(), deviceName: "Fixture")
        let date = Date()
        recording.receive(RowerSnapshot(date: date, elapsed: 0, distance: 100), workoutElapsed: 0)
        // Distances respect the existing plausibility limits.
        for second in 1...100 {
            recording.receive(RowerSnapshot(date: date.addingTimeInterval(Double(second)), elapsed: Double(second), distance: 100 + Double(second) * 5), workoutElapsed: Double(second))
        }
        let log = WorkoutCompletion(workout: workout, durationSeconds: 100, effort: 2, discomfort: false,
                                    note: "", manuallyRecorded: false, pm5: recording)
        XCTAssertFalse(log.finishedPlan)
        XCTAssertEqual(RowingJourney(completions: [log, log]).meters, 500)
        var second = log; second.id = UUID()
        XCTAssertEqual(RowingJourney(completions: [log, second]).meters, 1_000)
        XCTAssertEqual(RowingJourney(completions: [second]).discovered.count, 1)
        var manual = log; manual.manuallyRecorded = true
        XCTAssertEqual(RowingJourney(completions: [manual]).meters, 0)
        let restored = try JSONDecoder().decode([WorkoutCompletion].self, from: JSONEncoder().encode([log, second]))
        XCTAssertEqual(RowingJourney(completions: restored).meters, 1_000)
    }
}
