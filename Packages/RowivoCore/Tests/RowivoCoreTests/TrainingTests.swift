import XCTest
@testable import RowivoCore

final class TrainingTests: XCTestCase {
    func testManualPlanAllowsEmptyPlansAndArbitraryBoundedSteps() throws {
        XCTAssertNoThrow(try ManualPlan.validate(.init(blocks: [])))
        let workout = Workout(kind: .endurance, segments: [.init(kind: .work, seconds: 30)], customName: "Quick row")
        XCTAssertNoThrow(try ManualPlan.validateWorkout(workout))
        var invalid = workout; invalid.segments[0].seconds = Int.max
        XCTAssertThrowsError(try ManualPlan.validateWorkout(invalid))
        invalid = workout; invalid.segments = [.init(kind: .rest, seconds: 60)]
        XCTAssertThrowsError(try ManualPlan.validateWorkout(invalid))
        invalid = workout; invalid.segments = (0..<5).map { _ in .init(kind: .work, seconds: 3600) }
        XCTAssertThrowsError(try ManualPlan.validateWorkout(invalid))
    }

    func testIntervalInsertionAndDuplicationUseIndependentIDs() throws {
        let segments = try ManualPlan.intervals(repetitions: 4, rowingSeconds: 120, restSeconds: 60, intensity: .steady)
        XCTAssertEqual(segments.map(\.kind), [.work, .rest, .work, .rest, .work, .rest, .work])
        XCTAssertEqual(segments.reduce(0) { $0 + $1.seconds }, 660)
        let original = Workout(kind: .intervals, segments: segments, customName: "Intervals")
        let copy = ManualPlan.duplicate(original)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertTrue(Set(copy.segments.map(\.id)).isDisjoint(with: original.segments.map(\.id)))
        XCTAssertEqual(copy.customName, original.customName)
        XCTAssertThrowsError(try ManualPlan.intervals(repetitions: Int.max, rowingSeconds: 120, restSeconds: 60, intensity: .steady))
    }

    func testManualReorderingUsesOriginalDestinationIndices() throws {
        XCTAssertEqual(try ManualPlan.moved(["a", "b", "c", "d"], from: IndexSet([0, 2]), to: 4), ["b", "d", "a", "c"])
        XCTAssertEqual(try ManualPlan.moved([1, 2, 3], from: IndexSet(integer: 2), to: 0), [3, 1, 2])
        XCTAssertThrowsError(try ManualPlan.moved([1, 2], from: IndexSet(integer: 2), to: 0))
    }

    func testEverySupportedProfileProducesBoundedCompleteWorkouts() throws {
        for frequency in 2...3 {
            for minutes in 15...60 {
                let profile = TrainingProfile(name: "Test", sessionsPerWeek: frequency, sessionMinutes: minutes)
                let plan = try PlanFactory.make(profile: profile)
                XCTAssertEqual(plan.blocks.count, 8)
                XCTAssertEqual(plan.workouts.count, frequency * 8)
                for workout in plan.workouts {
                    XCTAssertLessThanOrEqual(workout.totalSeconds, minutes * 60)
                    XCTAssertEqual(workout.segments.first?.kind, .warmup)
                    XCTAssertEqual(workout.segments.last?.kind, .cooldown)
                    XCTAssertGreaterThan(workout.workSeconds, 0)
                }
            }
        }
    }

    func testInvalidProfileIsRejected() {
        XCTAssertThrowsError(try PlanFactory.make(profile: .init(name: "   ")))
        XCTAssertThrowsError(try PlanFactory.make(profile: .init(name: "T", sessionsPerWeek: 7)))
    }

    func testNextWorkoutSkipsCompletedIDsAndEndsAtCompletion() throws {
        let plan = try PlanFactory.make(profile: .init(name: "T"))
        let logs = plan.workouts.map(log)
        XCTAssertNil(PlanEngine.next(in: plan, completions: logs))
        XCTAssertEqual(PlanEngine.next(in: plan, completions: Array(logs.prefix(2)))?.id, plan.workouts[2].id)
    }

    func testRestDayUsesCalendarAcrossDaylightSavingTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        let plan = try PlanFactory.make(profile: .init(name: "T"))
        var completion = log(plan.workouts[0])
        completion.date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 20))!
        let available = try XCTUnwrap(PlanEngine.availableDate(completions: [completion], calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.day, .hour], from: available), DateComponents(day: 30, hour: 0))
        XCTAssertFalse(PlanEngine.canTrain(completions: [completion], now: available.addingTimeInterval(-1), calendar: calendar))
        XCTAssertTrue(PlanEngine.canTrain(completions: [completion], now: available, calendar: calendar))
    }

    func testAdjustmentCannotIncreaseDurationOrApplyTwice() throws {
        let profile = TrainingProfile(name: "T")
        let plan = try PlanFactory.make(profile: profile)
        var pending = PendingAdjustment(adjustment: .init(action: .shortenNext, value: 40, reason: "Time"), baseRevision: plan.revision, nextWorkoutID: plan.workouts[0].id)
        XCTAssertThrowsError(try PlanEngine.apply(pending, to: plan, profile: profile, completions: []))
        pending.adjustment.value = 20
        let adjusted = try PlanEngine.apply(pending, to: plan, profile: profile, completions: [])
        XCTAssertEqual(adjusted.workouts[0].totalSeconds, 1200)
        XCTAssertEqual(adjusted.workouts[0].id, plan.workouts[0].id)
        XCTAssertThrowsError(try PlanEngine.apply(pending, to: adjusted, profile: profile, completions: []))
    }

    func testCompletingWorkoutInvalidatesEarlierSuggestion() throws {
        let profile = TrainingProfile(name: "T")
        let plan = try PlanFactory.make(profile: profile)
        let pending = PendingAdjustment(adjustment: .init(action: .easeNext, reason: "Easy"), baseRevision: plan.revision, nextWorkoutID: plan.workouts[0].id)
        XCTAssertThrowsError(try PlanEngine.apply(pending, to: plan, profile: profile, completions: [log(plan.workouts[0])]))
    }

    func testRepeatRetainsHistoryAndGivesRepeatedWorkoutsNewIDs() throws {
        let profile = TrainingProfile(name: "T")
        let plan = try PlanFactory.make(profile: profile)
        let completed = plan.blocks[0].workouts.map(log)
        let pending = PendingAdjustment(adjustment: .init(action: .repeatLastBlock, reason: "Repeat"), baseRevision: plan.revision, nextWorkoutID: plan.workouts[3].id)
        let result = try PlanEngine.apply(pending, to: plan, profile: profile, completions: completed)
        XCTAssertEqual(result.blocks[0], plan.blocks[0])
        XCTAssertTrue(result.blocks[1].isRepeat)
        XCTAssertEqual(result.blocks[1].week, 1)
        XCTAssertEqual(Set(result.workouts.map(\.id)).count, result.workouts.count)
        XCTAssertEqual(PlanEngine.next(in: result, completions: completed)?.id, result.blocks[1].workouts[0].id)
    }

    func testReducedFrequencyPreservesCompletedSessions() throws {
        let profile = TrainingProfile(name: "T")
        let plan = try PlanFactory.make(profile: profile)
        let completed = Array(plan.workouts.prefix(2)).map(log)
        let pending = PendingAdjustment(adjustment: .init(action: .reduceFrequency, value: 2, reason: "Time"), baseRevision: plan.revision, nextWorkoutID: plan.workouts[2].id)
        let result = try PlanEngine.apply(pending, to: plan, profile: profile, completions: completed)
        XCTAssertEqual(result.blocks[0].workouts.map(\.id), completed.map(\.workoutID))
        XCTAssertTrue(result.blocks.allSatisfy { $0.workouts.count == 2 })
    }

    func testClockSurvivesEncodingAndDoesNotCountPausedTime() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var clock = WorkoutClock(workoutID: UUID(), now: start)
        clock.pause(at: start.addingTimeInterval(60))
        clock = try JSONDecoder().decode(WorkoutClock.self, from: JSONEncoder().encode(clock))
        XCTAssertEqual(clock.elapsed(at: start.addingTimeInterval(600)), 60)
        clock.resume(at: start.addingTimeInterval(600))
        XCTAssertEqual(clock.elapsed(at: start.addingTimeInterval(630)), 90)
        clock.resume(at: start.addingTimeInterval(620))
        XCTAssertEqual(clock.elapsed(at: start.addingTimeInterval(630)), 90)
    }

    func testSegmentBoundariesAndEnd() {
        let workout = Workout(kind: .technique, segments: [.init(kind: .warmup, seconds: 180), .init(kind: .work, seconds: 300), .init(kind: .cooldown, seconds: 180)])
        XCTAssertEqual(workout.segment(at: 180)?.index, 1)
        XCTAssertEqual(workout.segment(at: 180)?.remaining, 300)
        XCTAssertNil(workout.segment(at: 660))
    }

    private func log(_ workout: Workout) -> WorkoutCompletion {
        .init(workout: workout, durationSeconds: workout.totalSeconds, effort: 2, discomfort: false, note: "", manuallyRecorded: true)
    }
}
