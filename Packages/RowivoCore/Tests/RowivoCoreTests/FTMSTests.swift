import XCTest
@testable import RowivoCore

final class FTMSTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    // Independent wire fixtures, including all ignored fields so offsets are checked.
    private let full = Data([
        0xFE, 0x1F, 45, 0x34, 0x12, // flags, 22.5 spm, stroke count
        44, 0x56, 0x34, 0x12,       // average spm, distance 0x123456
        0x7D, 0, 0x80, 0,          // pace 125, average pace
        0xEC, 0xFF, 0xB4, 0,       // -20 W, average power
        7, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // one-byte resistance, unavailable energy
        142, 25, 0x2C, 1, 0x58, 2  // HR, MET, elapsed 300, remaining
    ])

    func testEveryFieldOffsetAndUnitsIncludingSignedPowerAndHalfStrokeRate() throws {
        let packet = try XCTUnwrap(FTMSPacket.decode(full, at: date))
        XCTAssertFalse(packet.moreData)
        XCTAssertEqual(packet.values.strokeRate, 22.5)
        XCTAssertEqual(packet.values.strokeCount, 0x1234)
        XCTAssertEqual(packet.values.distance, 0x123456)
        XCTAssertEqual(packet.values.pace, 125)
        XCTAssertEqual(packet.values.watts, -20)
        XCTAssertEqual(packet.values.heartRate, 142)
        XCTAssertEqual(packet.values.elapsed, 300)
    }

    func testMinimumRecordDoesNotInventOptionalMetrics() throws {
        let values = try XCTUnwrap(FTMSPacket.decode(Data([0, 0, 41, 2, 0]), at: date)).values
        XCTAssertEqual(values.strokeRate, 20.5)
        XCTAssertNil(values.distance); XCTAssertNil(values.elapsed)
        XCTAssertNil(values.pace); XCTAssertNil(values.watts); XCTAssertNil(values.heartRate)
    }

    func testEveryTruncatedLengthReservedFlagsAndTrailingBytesRejected() {
        for length in 0..<full.count {
            XCTAssertNil(FTMSPacket.decode(full.prefix(length), at: date), "length \(length)")
        }
        XCTAssertNil(FTMSPacket.decode(full + Data([0]), at: date))
        XCTAssertNil(FTMSPacket.decode(Data([0, 0x20, 40, 0, 0]), at: date))
        XCTAssertNil(FTMSPacket.decode(Data([0, 0]), at: date))
    }

    func testSplitRecordPublishedOnlyAtFinalAndNextRecordDropsOldMetrics() throws {
        var telemetry = FTMSTelemetry()
        XCTAssertNil(telemetry.receive(Data([0x0D, 8, 100, 0, 0, 125, 0, 10, 0]), at: date))
        // Elapsed time repeats in each fragment of this record.
        let result = try XCTUnwrap(telemetry.receive(Data([0x20, 10, 45, 3, 0, 180, 0, 140, 10, 0]), at: date.addingTimeInterval(0.1)))
        XCTAssertEqual(result.distance, 100); XCTAssertEqual(result.elapsed, 10)
        XCTAssertEqual(result.pace, 125); XCTAssertEqual(result.watts, 180)
        XCTAssertEqual(result.strokeRate, 22.5); XCTAssertEqual(result.heartRate, 140)
        let next = try XCTUnwrap(telemetry.receive(Data([0, 0, 40, 4, 0]), at: date.addingTimeInterval(1)))
        XCTAssertNil(next.distance); XCTAssertNil(next.pace); XCTAssertNil(next.heartRate)
    }

    func testStaleMalformedAndDifferentTimeFragmentsAreNotMerged() throws {
        for mode in 0...2 {
            var telemetry = FTMSTelemetry()
            XCTAssertNil(telemetry.receive(Data([5, 8, 100, 0, 0, 10, 0]), at: date))
            if mode == 1 { XCTAssertNil(telemetry.receive(Data([2]), at: date)) }
            let final = Data([0, 8, 40, 0, 0, mode == 2 ? 11 : 10, 0])
            let result = try XCTUnwrap(telemetry.receive(final, at: date.addingTimeInterval(mode == 0 ? 3 : 0.1)))
            XCTAssertNil(result.distance)
        }
    }

    func testRecordingWithoutCountersPersistsAndWatchKeepsMissingDistance() throws {
        var recording = RowerRecording(deviceID: UUID(), deviceName: "FTMS test", deviceProtocol: .ftms)
        let snapshot = RowerSnapshot(date: date, strokeRate: 22.5, strokeCount: 10, watts: 180)
        recording.receive(snapshot, workoutElapsed: 0)
        recording.receive(.init(date: date.addingTimeInterval(1), strokeRate: 23), workoutElapsed: 1)
        XCTAssertTrue(recording.hasMeasurements)
        XCTAssertNil(recording.measuredDistance); XCTAssertNil(recording.measuredTime); XCTAssertNil(recording.averagePace)
        let restored = try JSONDecoder().decode(RowerRecording.self, from: JSONEncoder().encode(recording))
        XCTAssertEqual(restored.deviceProtocol, .ftms); XCTAssertEqual(restored.samples.first?.strokeRate, 22.5)
        let metrics = WatchMetrics(snapshot: snapshot, distance: recording.measuredDistance)
        let watch = WatchSnapshot(controlToken: UUID(), availability: .noProfile, metrics: metrics)
        let decoded = try WatchWire.decode(WatchSnapshot.self, from: WatchWire.encode(watch))
        try decoded.validate()
        XCTAssertNil(decoded.metrics?.distance); XCTAssertEqual(decoded.metrics?.strokeRate, 22.5)
    }

    func testDistanceOnlyCountsReceivedDeltasAndExcludesResetPauseAndMissingSpans() {
        var recording = RowerRecording(deviceID: UUID(), deviceName: "FTMS test", deviceProtocol: .ftms)
        func feed(_ time: Double, _ meters: Double?) {
            recording.receive(RowerSnapshot(date: date.addingTimeInterval(time), distance: meters, strokeRate: 22), workoutElapsed: time)
        }
        feed(0, 100); feed(1, 104)
        feed(2, nil); feed(3, 120); feed(4, 124)
        feed(5, 0); feed(6, 4)
        recording.breakContinuity(isGap: false)
        feed(9, 30); feed(10, 34)
        XCTAssertEqual(recording.measuredDistance, 16)
        XCTAssertNil(recording.measuredTime); XCTAssertNil(recording.averagePace)
        XCTAssertTrue(recording.hasGaps)
    }

    func testMissingCountersBetweenPersistedSamplesNeverProduceAnAverage() throws {
        var recording = RowerRecording(deviceID: UUID(), deviceName: "FTMS test", deviceProtocol: .ftms)
        recording.receive(RowerSnapshot(date: date, elapsed: 0, distance: 0), workoutElapsed: 0)
        recording.receive(RowerSnapshot(date: date.addingTimeInterval(0.2), elapsed: 0), workoutElapsed: 0.2)
        recording.receive(RowerSnapshot(date: date.addingTimeInterval(0.5), elapsed: 0, distance: 2), workoutElapsed: 0.5)
        recording.receive(RowerSnapshot(date: date.addingTimeInterval(1), elapsed: 1, distance: 4), workoutElapsed: 1)
        XCTAssertEqual(recording.samples.count, 2)
        XCTAssertNil(recording.averagePace)
        let restored = try JSONDecoder().decode(RowerRecording.self, from: JSONEncoder().encode(recording))
        XCTAssertNil(restored.averagePace)
    }

    func testLegacyRecordingWithoutProtocolOrStrokeCountRemainsConcept2() throws {
        let id = UUID()
        let json = """
        {"deviceID":"\(id)","deviceName":"PM5","distance":4,"rowingSeconds":1,"hasGaps":false,"segment":0,
         "samples":[{"id":0,"date":100,"workoutElapsed":1,"monitorElapsed":1,"monitorDistance":4,
         "recordedDistance":4,"strokeRate":22,"segment":0}]}
        """
        let recording = try JSONDecoder().decode(RowerRecording.self, from: Data(json.utf8))
        XCTAssertEqual(recording.deviceProtocol, .concept2)
        XCTAssertEqual(recording.measuredDistance, 4); XCTAssertEqual(recording.averagePace, 125)
        XCTAssertEqual(recording.samples[0].strokeRate, 22); XCTAssertNil(recording.samples[0].strokeCount)
    }
}
