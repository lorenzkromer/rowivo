import XCTest
@testable import RowivoCore

final class AutoPauseTests: XCTestCase {
    func testDebounceAndHysteresis() {
        var detector = PowerPauseDetector()
        let start = Date()
        for second in 0..<6 {
            XCTAssertNil(detector.receive(watts: 5, at: start.addingTimeInterval(Double(second)), threshold: 6, running: true, automaticallyPaused: false, resting: false))
        }
        XCTAssertEqual(detector.receive(watts: 5, at: start.addingTimeInterval(6), threshold: 6, running: true, automaticallyPaused: false, resting: false), .pause)
        for second in 7...9 {
            XCTAssertNil(detector.receive(watts: 9, at: start.addingTimeInterval(Double(second)), threshold: 6, running: false, automaticallyPaused: true, resting: false))
        }
        for second in 10..<12 {
            XCTAssertNil(detector.receive(watts: 10, at: start.addingTimeInterval(Double(second)), threshold: 6, running: false, automaticallyPaused: true, resting: false))
        }
        XCTAssertEqual(detector.receive(watts: 10, at: start.addingTimeInterval(12), threshold: 6, running: false, automaticallyPaused: true, resting: false), .resume)
    }
    func testPlannedRestsManualPausesMissingDataAndGapsNeverTrigger() {
        for mode in 0...3 {
            var detector = PowerPauseDetector()
            for second in 0...20 {
                XCTAssertNil(detector.receive(watts: mode == 2 ? nil : (mode == 1 ? 100 : 0),
                    at: Date(timeIntervalSince1970: Double(second * (mode == 3 ? 5 : 1))), threshold: 6,
                    running: mode != 1, automaticallyPaused: false, resting: mode == 0))
            }
        }
    }
    func testShortDipAndThresholdDoNotAccumulate() {
        var detector = PowerPauseDetector()
        for second in 0...20 {
            XCTAssertNil(detector.receive(watts: second % 5 == 0 ? 6 : 0, at: Date(timeIntervalSince1970: Double(second)),
                threshold: 6, running: true, automaticallyPaused: false, resting: false))
        }
    }
}
