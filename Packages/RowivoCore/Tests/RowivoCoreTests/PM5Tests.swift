import XCTest
@testable import RowivoCore

final class PM5Tests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    private func data(count: Int, fields: [(Int, Int, Int)]) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        for (offset, length, value) in fields {
            for i in 0..<length { bytes[offset + i] = UInt8((value >> (8 * i)) & 255) }
        }
        return Data(bytes)
    }
    private func snapshot(_ wall: Double, elapsed: Double, distance: Double) -> PM5Snapshot {
        .init(date: epoch.addingTimeInterval(wall), general: .init(elapsed: elapsed, distance: distance))
    }

    func testGeneralStatusLittleEndianUnitsAndStates() throws {
        let bytes = data(count: 19, fields: [(0,3,12345), (3,3,23456), (6,1,5), (8,1,1), (9,1,1), (18,1,118)])
        guard case .general(let status) = PM5Packet.decode(characteristic: 0x31, data: bytes) else { return XCTFail("Missing general status") }
        XCTAssertEqual(status.elapsed, 123.45)
        XCTAssertEqual(status.distance, 2345.6)
        XCTAssertEqual(status.workoutType, 5)
        XCTAssertEqual(status.workoutState, 1)
        XCTAssertEqual(status.rowingState, 1)
        XCTAssertEqual(status.dragFactor, 118)
    }

    func testAdditionalAndStrokeFieldsForOldAndCurrentFirmware() {
        for count in [16, 17] {
            let bytes = data(count: count, fields: [(0,3,70000), (3,2,3200), (5,1,24), (6,1,142), (7,2,15625), (9,2,16000)])
            guard case .additional(let value) = PM5Packet.decode(characteristic: 0x32, data: bytes) else { return XCTFail() }
            XCTAssertEqual(value.elapsed, 700); XCTAssertEqual(value.pace, 156.25)
            XCTAssertEqual(value.strokeRate, 24); XCTAssertEqual(value.heartRate, 142)
        }
        for count in [15, 18] {
            let bytes = data(count: count, fields: [(0,3,70000), (3,2,187), (5,2,900), (7,2,321)])
            guard case .stroke(let value) = PM5Packet.decode(characteristic: 0x36, data: bytes) else { return XCTFail() }
            XCTAssertEqual(value.elapsed, 700); XCTAssertEqual(value.watts, 187); XCTAssertEqual(value.count, 321)
        }
    }

    func testTruncatedUnknownAndInvalidReadings() {
        for (id, minimum) in [(UInt16(0x31), 19), (0x32,16), (0x36,15)] {
            for count in 0..<minimum { XCTAssertNil(PM5Packet.decode(characteristic: id, data: Data(repeating: 0, count: count))) }
        }
        XCTAssertNil(PM5Packet.decode(characteristic: 0x80, data: Data(repeating: 0, count: 30)))
        for heart in [0,255] {
            for pace in [0,65535] {
                let bytes = data(count: 17, fields: [(6,1,heart), (7,2,pace)])
                guard case .additional(let value) = PM5Packet.decode(characteristic: 0x32, data: bytes) else { return XCTFail() }
                XCTAssertNil(value.heartRate); XCTAssertNil(value.pace)
            }
        }
    }

    func testTelemetryNeverReusesStaleValuesOrOldWorkout() throws {
        var telemetry = PM5Telemetry()
        let additional = try XCTUnwrap(PM5Packet.decode(characteristic: 0x32, data: data(count: 17, fields: [(0,3,10000), (5,1,22), (6,1,255), (7,2,14500)])))
        XCTAssertNil(telemetry.receive(additional, at: epoch))
        let fresh = try XCTUnwrap(telemetry.receive(.general(.init(elapsed: 100, distance: 20)), at: epoch))
        XCTAssertEqual(fresh.pace, 145); XCTAssertNil(fresh.heartRate)
        let stale = try XCTUnwrap(telemetry.receive(.general(.init(elapsed: 100, distance: 20)), at: epoch.addingTimeInterval(4)))
        XCTAssertNil(stale.pace)
        _ = telemetry.receive(additional, at: epoch.addingTimeInterval(5))
        let reset = try XCTUnwrap(telemetry.receive(.general(.init(elapsed: 0, distance: 0)), at: epoch.addingTimeInterval(5)))
        XCTAssertNil(reset.pace)
    }

    func testSessionExcludesExistingMetersAndAppPause() {
        var recording = PM5Recording(deviceID: UUID(), deviceName: "PM5 Test")
        recording.receive(snapshot(0, elapsed: 600, distance: 2000), workoutElapsed: 0)
        recording.receive(snapshot(1, elapsed: 601, distance: 2004), workoutElapsed: 1)
        XCTAssertEqual(recording.distance, 4); XCTAssertEqual(recording.rowingSeconds, 1)
        recording.breakContinuity(isGap: false)
        recording.receive(snapshot(50, elapsed: 650, distance: 2190), workoutElapsed: 1)
        recording.receive(snapshot(51, elapsed: 651, distance: 2194), workoutElapsed: 2)
        XCTAssertEqual(recording.distance, 8); XCTAssertEqual(recording.rowingSeconds, 2)
        XCTAssertEqual(recording.averagePace, 125); XCTAssertFalse(recording.hasGaps)
    }

    func testMissingPacketsReconnectAndResetAreExcludedAndMarked() {
        var recording = PM5Recording(deviceID: UUID(), deviceName: "PM5 Test", startsLate: true)
        recording.receive(snapshot(0, elapsed: 0, distance: 0), workoutElapsed: 10)
        recording.receive(snapshot(1, elapsed: 1, distance: 4), workoutElapsed: 11)
        recording.receive(snapshot(20, elapsed: 20, distance: 80), workoutElapsed: 30)
        recording.receive(snapshot(21, elapsed: 21, distance: 84), workoutElapsed: 31)
        recording.receive(snapshot(22, elapsed: 0, distance: 0), workoutElapsed: 32)
        recording.receive(snapshot(23, elapsed: 1, distance: 4), workoutElapsed: 33)
        recording.breakContinuity(isGap: true)
        recording.receive(snapshot(24, elapsed: 2, distance: 8), workoutElapsed: 34)
        XCTAssertEqual(recording.distance, 12); XCTAssertEqual(recording.rowingSeconds, 3)
        XCTAssertTrue(recording.hasGaps)
        XCTAssertEqual(recording.samples.last?.segment, 3)
    }

    func testRateLimitDoesNotLoseCounterDeltasAndRejectsOutOfOrder() {
        var recording = PM5Recording(deviceID: UUID(), deviceName: "PM5 Test")
        for i in 0...20 {
            recording.receive(snapshot(Double(i) / 10, elapsed: Double(i) / 10, distance: Double(i) / 2), workoutElapsed: Double(i) / 10)
        }
        XCTAssertEqual(recording.distance, 10); XCTAssertEqual(recording.samples.count, 3)
        recording.receive(snapshot(1, elapsed: 1, distance: 5), workoutElapsed: 1)
        recording.receive(snapshot(3, elapsed: 3, distance: 15), workoutElapsed: 3)
        XCTAssertEqual(recording.distance, 15)
    }

    func testPersistenceDoesNotBridgeAppTermination() throws {
        var original = PM5Recording(deviceID: UUID(), deviceName: "PM5 Test")
        original.receive(snapshot(0, elapsed: 0, distance: 0), workoutElapsed: 0)
        original.receive(snapshot(1, elapsed: 1, distance: 4), workoutElapsed: 1)
        var reopened = try JSONDecoder().decode(PM5Recording.self, from: JSONEncoder().encode(original))
        reopened.breakContinuity(isGap: true)
        reopened.receive(snapshot(2, elapsed: 2, distance: 8), workoutElapsed: 2)
        reopened.receive(snapshot(3, elapsed: 3, distance: 12), workoutElapsed: 3)
        XCTAssertEqual(reopened.distance, 8); XCTAssertTrue(reopened.hasGaps)
        XCTAssertEqual(reopened.deviceID, original.deviceID)
    }

    func testExistingCompletionJSONWithoutPM5StillLoads() throws {
        let workout = try PlanFactory.make(profile: .init(name: "Alex")).workouts[0]
        let log = WorkoutCompletion(workout: workout, durationSeconds: 60, effort: 2, discomfort: false, note: "", manuallyRecorded: true)
        let bytes = try JSONEncoder().encode(log)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        legacy.removeValue(forKey: "pm5")
        let reopened = try JSONDecoder().decode(WorkoutCompletion.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(reopened.id, log.id); XCTAssertNil(reopened.pm5)
    }
}
