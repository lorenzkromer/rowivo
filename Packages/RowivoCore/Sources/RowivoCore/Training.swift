import Foundation

public enum TrainingGoal: String, CaseIterable, Codable, Sendable {
    case routine = "Build a routine", fitness = "Feel fitter", endurance = "Build endurance"
}

public enum Experience: String, CaseIterable, Codable, Sendable {
    case beginner = "New to rowing", returning = "Getting back into it"
}

public struct TrainingProfile: Codable, Equatable, Sendable {
    public var name: String
    public var goal: TrainingGoal
    public var experience: Experience
    public var sessionsPerWeek: Int
    public var sessionMinutes: Int
    public init(name: String, goal: TrainingGoal = .routine, experience: Experience = .beginner,
                sessionsPerWeek: Int = 3, sessionMinutes: Int = 30) {
        self.name = name; self.goal = goal; self.experience = experience
        self.sessionsPerWeek = sessionsPerWeek; self.sessionMinutes = sessionMinutes
    }
}

public enum SegmentKind: String, CaseIterable, Codable, Sendable { case warmup = "Warm up", work = "Row", rest = "Rest", cooldown = "Cool down" }
public enum Intensity: String, CaseIterable, Codable, Sendable { case easy = "Easy", steady = "Steady" }
public enum WorkoutKind: String, CaseIterable, Codable, Sendable {
    case technique = "Find your rhythm", endurance = "Build your base", intervals = "Change the rhythm", recovery = "An easy row"
}

public struct WorkoutSegment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: SegmentKind
    public var seconds: Int
    public var intensity: Intensity
    public init(kind: SegmentKind, seconds: Int, intensity: Intensity = .easy) {
        id = UUID(); self.kind = kind; self.seconds = seconds; self.intensity = intensity
    }
}

public struct Workout: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: WorkoutKind
    public var segments: [WorkoutSegment]
    public var customName: String?
    public var totalSeconds: Int { segments.reduce(0) { $0 + $1.seconds } }
    public var workSeconds: Int { segments.filter { $0.kind == .work }.reduce(0) { $0 + $1.seconds } }
    public var minutes: Int { Int(ceil(Double(totalSeconds) / 60)) }
    public init(kind: WorkoutKind, segments: [WorkoutSegment], customName: String? = nil) {
        id = UUID(); self.kind = kind; self.segments = segments; self.customName = customName
    }
    public func segment(at elapsed: TimeInterval) -> (index: Int, remaining: Int)? {
        var remaining = max(0, Int(elapsed))
        for (index, segment) in segments.enumerated() {
            if remaining < segment.seconds { return (index, segment.seconds - remaining) }
            remaining -= segment.seconds
        }
        return nil
    }
}

public struct TrainingBlock: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var week: Int
    public var isRepeat: Bool
    public var workouts: [Workout]
    public init(week: Int, workouts: [Workout], isRepeat: Bool = false) {
        id = UUID(); self.week = week; self.workouts = workouts; self.isRepeat = isRepeat
    }
    public var phase: String { week <= 2 ? "Technique" : week <= 6 ? "Foundation" : "Consistency" }
}

public struct TrainingPlan: Codable, Equatable, Sendable {
    public var revision: Int = 1
    public var blocks: [TrainingBlock]
    public var workouts: [Workout] { blocks.flatMap(\.workouts) }
    public init(blocks: [TrainingBlock]) { self.blocks = blocks }
    public func block(for workout: UUID) -> TrainingBlock? { blocks.first { $0.workouts.contains { $0.id == workout } } }
}

public struct WorkoutCompletion: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var workoutID: UUID
    public var title: WorkoutKind
    /// When the workout happened. Legacy entries used their save time.
    public var date: Date
    /// Kept separately for backdated entries; absent in older local data and backups.
    public var recordedAt: Date?
    /// Last manual correction to the saved session. Original sensor samples stay intact.
    public var editedAt: Date? = nil
    public var durationSeconds: Int
    public var effort: Int
    public var discomfort: Bool
    public var note: String
    public var manuallyRecorded: Bool
    public var finishedPlan: Bool
    public var pm5: PM5Recording?
    public var customName: String?
    public init(workout: Workout, date: Date = Date(), durationSeconds: Int, effort: Int,
                discomfort: Bool, note: String, manuallyRecorded: Bool, pm5: PM5Recording? = nil, recordedAt: Date? = nil) {
        id = UUID(); workoutID = workout.id; title = workout.kind; self.date = date
        self.durationSeconds = durationSeconds; self.effort = effort; self.discomfort = discomfort
        self.note = note; self.manuallyRecorded = manuallyRecorded
        self.pm5 = manuallyRecorded ? nil : pm5
        self.recordedAt = recordedAt
        customName = workout.customName
        finishedPlan = durationSeconds >= workout.totalSeconds
    }
}

public enum PlanError: Error, Equatable, Sendable {
    case invalidProfile, invalidWorkout, invalidAdjustment, staleProposal, noUpcomingWorkout
    case noCompletedBlock, duplicateCompletion, restDay, needsCheckIn, invalidTrainingDate
}

public enum PlanFactory {
    /// Application template, not a medically validated prescription. No inferred heart-rate zones.
    public static func make(profile: TrainingProfile) throws -> TrainingPlan {
        guard (2...3).contains(profile.sessionsPerWeek), (15...60).contains(profile.sessionMinutes),
              !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PlanError.invalidProfile }
        let blocks = (1...8).map { week in
            TrainingBlock(week: week, workouts: (0..<profile.sessionsPerWeek).map { day in
                let kind: WorkoutKind = week <= 2 ? .technique : day == 1 ? .intervals : .endurance
                var segments = [WorkoutSegment(kind: .warmup, seconds: 240)]
                if week <= 2 {
                    for index in 0..<4 {
                        segments.append(.init(kind: .work, seconds: week == 1 ? 300 : 360))
                        if index < 3 { segments.append(.init(kind: .rest, seconds: week == 1 ? 120 : 90)) }
                    }
                } else if kind == .intervals {
                    // Controlled steady efforts; the original draft's high-intensity prescriptions are not automatic.
                    let rounds = week < 5 ? 6 : 8
                    for index in 0..<rounds {
                        segments.append(.init(kind: .work, seconds: 60, intensity: .steady))
                        if index < rounds - 1 { segments.append(.init(kind: .rest, seconds: 60)) }
                    }
                } else {
                    let mainMinutes = [20, 25, 30, 30, 35, 40][week - 3]
                    segments.append(.init(kind: .work, seconds: mainMinutes * 60, intensity: .steady))
                }
                segments.append(.init(kind: .cooldown, seconds: 180))
                return fit(Workout(kind: kind, segments: segments), to: profile.sessionMinutes * 60)
            })
        }
        let plan = TrainingPlan(blocks: blocks)
        try validate(plan, maximumMinutes: profile.sessionMinutes)
        return plan
    }

    public static func fit(_ workout: Workout, to seconds: Int) -> Workout {
        guard workout.totalSeconds > seconds else { return workout }
        var result = workout
        while result.totalSeconds - result.workSeconds + result.segments.filter({ $0.kind == .work }).count * 30 > seconds {
            guard result.segments.filter({ $0.kind == .work }).count > 1,
                  let lastWork = result.segments.lastIndex(where: { $0.kind == .work }),
                  lastWork > 0, result.segments[lastWork - 1].kind == .rest else { break }
            result.segments.removeSubrange((lastWork - 1)...lastWork)
        }
        let workIndices = result.segments.indices.filter { result.segments[$0].kind == .work }
        let fixed = result.totalSeconds - result.workSeconds
        let budget = max(workIndices.count * 30, seconds - fixed)
        let perSegment = budget / max(1, workIndices.count)
        for (offset, index) in workIndices.enumerated() {
            result.segments[index].seconds = perSegment + (offset < budget % max(1, workIndices.count) ? 1 : 0)
        }
        return result
    }

    public static func validate(_ plan: TrainingPlan, maximumMinutes: Int) throws {
        guard !plan.blocks.isEmpty, Set(plan.workouts.map(\.id)).count == plan.workouts.count else { throw PlanError.invalidWorkout }
        for block in plan.blocks {
            guard (1...8).contains(block.week), !block.workouts.isEmpty else { throw PlanError.invalidWorkout }
            for workout in block.workouts {
                guard workout.segments.first?.kind == .warmup, workout.segments.last?.kind == .cooldown,
                      workout.segments.first!.seconds >= 180, workout.segments.last!.seconds >= 180,
                      workout.totalSeconds <= maximumMinutes * 60, workout.workSeconds > 0,
                      workout.segments.allSatisfy({ $0.seconds > 0 }) else { throw PlanError.invalidWorkout }
            }
        }
    }
}

public enum ManualPlanError: Error, Equatable {
    case noRowing, invalidDuration, tooLong, tooManySteps, invalidPlan, nameTooLong
    case activeWorkout, recordedWorkout, staleEdit, missingWorkout, capacity
}

/// Rules for user-authored workouts. Template-specific coaching rules remain separate.
public enum ManualPlan {
    public static func validateWorkout(_ workout: Workout) throws {
        guard workout.segments.count <= 100 else { throw ManualPlanError.tooManySteps }
        guard workout.customName.map({ $0.count <= 80 }) ?? true else { throw ManualPlanError.nameTooLong }
        guard !workout.segments.isEmpty, workout.segments.contains(where: { $0.kind == .work }) else { throw ManualPlanError.noRowing }
        // Check individual values before summing untrusted imported durations.
        guard workout.segments.allSatisfy({ (1...3600).contains($0.seconds) }),
              Set(workout.segments.map(\.id)).count == workout.segments.count else { throw ManualPlanError.invalidDuration }
        guard workout.totalSeconds <= 14_400 else { throw ManualPlanError.tooLong }
    }

    public static func validate(_ plan: TrainingPlan) throws {
        guard (1...1_000_000).contains(plan.revision), plan.blocks.count <= 1_000,
              plan.workouts.count <= 10_000,
              Set(plan.blocks.map(\.id)).count == plan.blocks.count,
              Set(plan.workouts.map(\.id)).count == plan.workouts.count,
              plan.blocks.allSatisfy({ (1...1_000).contains($0.week) && $0.workouts.count <= 100 }) else { throw ManualPlanError.invalidPlan }
        for workout in plan.workouts { try validateWorkout(workout) }
    }

    public static func duplicate(_ workout: Workout) -> Workout {
        Workout(kind: workout.kind, segments: workout.segments.map {
            WorkoutSegment(kind: $0.kind, seconds: $0.seconds, intensity: $0.intensity)
        }, customName: workout.customName)
    }

    public static func moved<Element>(_ values: [Element], from offsets: IndexSet, to destination: Int) throws -> [Element] {
        guard (0...values.count).contains(destination), offsets.allSatisfy({ values.indices.contains($0) }) else { throw ManualPlanError.invalidPlan }
        let selected = offsets.sorted().map { values[$0] }
        var remaining = values.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        remaining.insert(contentsOf: selected, at: destination - offsets.filter { $0 < destination }.count)
        return remaining
    }

    public static func intervals(repetitions: Int, rowingSeconds: Int, restSeconds: Int, intensity: Intensity) throws -> [WorkoutSegment] {
        guard (2...20).contains(repetitions), (1...3600).contains(rowingSeconds), (1...3600).contains(restSeconds) else { throw ManualPlanError.invalidDuration }
        var segments: [WorkoutSegment] = []
        for index in 0..<repetitions {
            segments.append(.init(kind: .work, seconds: rowingSeconds, intensity: intensity))
            if index < repetitions - 1 { segments.append(.init(kind: .rest, seconds: restSeconds)) }
        }
        return segments
    }
}

public enum AdjustmentAction: String, Codable, Sendable { case shortenNext = "shorten_next", easeNext = "ease_next", repeatLastBlock = "repeat_last_block", reduceFrequency = "reduce_frequency" }

public struct CoachAdjustment: Codable, Equatable, Sendable {
    public var action: AdjustmentAction
    public var value: Int
    public var reason: String
    public init(action: AdjustmentAction, value: Int = 0, reason: String) { self.action = action; self.value = value; self.reason = reason }
}

public struct PendingAdjustment: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var adjustment: CoachAdjustment
    public var baseRevision: Int
    public var nextWorkoutID: UUID
    public init(adjustment: CoachAdjustment, baseRevision: Int, nextWorkoutID: UUID) {
        self.adjustment = adjustment; self.baseRevision = baseRevision; self.nextWorkoutID = nextWorkoutID
    }
}

public enum PlanEngine {
    public static func next(in plan: TrainingPlan, completions: [WorkoutCompletion]) -> Workout? {
        let completed = Set(completions.filter(\.finishedPlan).map(\.workoutID))
        return plan.workouts.first { !completed.contains($0.id) }
    }

    public static func availableDate(completions: [WorkoutCompletion], calendar: Calendar = .current) -> Date? {
        guard let latest = completions.map(\.date).max() else { return nil }
        return calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: latest))
    }

    public static func canTrain(completions: [WorkoutCompletion], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let available = availableDate(completions: completions, calendar: calendar) else { return true }
        return now >= available
    }

    public static func apply(_ pending: PendingAdjustment, to plan: TrainingPlan,
                             profile: TrainingProfile, completions: [WorkoutCompletion]) throws -> TrainingPlan {
        guard pending.baseRevision == plan.revision,
              let next = next(in: plan, completions: completions), next.id == pending.nextWorkoutID else { throw PlanError.staleProposal }
        let adjustment = pending.adjustment
        guard !adjustment.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              adjustment.reason.count <= 2000 else { throw PlanError.invalidAdjustment }
        var result = plan
        let blockIndex = result.blocks.firstIndex { $0.workouts.contains { $0.id == next.id } }!
        let workoutIndex = result.blocks[blockIndex].workouts.firstIndex { $0.id == next.id }!
        switch adjustment.action {
        case .shortenNext:
            guard (15...profile.sessionMinutes).contains(adjustment.value), adjustment.value * 60 < next.totalSeconds else { throw PlanError.invalidAdjustment }
            result.blocks[blockIndex].workouts[workoutIndex] = PlanFactory.fit(next, to: adjustment.value * 60)
        case .easeNext:
            result.blocks[blockIndex].workouts[workoutIndex].kind = .recovery
            for index in next.segments.indices { result.blocks[blockIndex].workouts[workoutIndex].segments[index].intensity = .easy }
        case .repeatLastBlock:
            let completed = Set(completions.filter(\.finishedPlan).map(\.workoutID))
            guard let previous = result.blocks[..<blockIndex].last(where: { $0.workouts.allSatisfy { completed.contains($0.id) } }) else { throw PlanError.noCompletedBlock }
            let repeated = TrainingBlock(week: previous.week, workouts: previous.workouts.map { Workout(kind: $0.kind, segments: $0.segments) }, isRepeat: true)
            result.blocks.insert(repeated, at: blockIndex)
        case .reduceFrequency:
            guard adjustment.value == 2, profile.sessionsPerWeek == 3 else { throw PlanError.invalidAdjustment }
            let completed = Set(completions.filter(\.finishedPlan).map(\.workoutID))
            for index in blockIndex..<result.blocks.count {
                let done = result.blocks[index].workouts.filter { completed.contains($0.id) }
                let remaining = result.blocks[index].workouts.filter { !completed.contains($0.id) }
                result.blocks[index].workouts = done + remaining.prefix(max(0, 2 - done.count))
            }
        }
        result.revision += 1
        try PlanFactory.validate(result, maximumMinutes: profile.sessionMinutes)
        return result
    }
}

public struct WorkoutClock: Codable, Equatable, Sendable {
    public var workoutID: UUID
    public private(set) var accumulated: TimeInterval
    public private(set) var resumedAt: Date?
    public init(workoutID: UUID, now: Date = Date()) { self.workoutID = workoutID; accumulated = 0; resumedAt = now }
    public func elapsed(at now: Date = Date()) -> TimeInterval { accumulated + (resumedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0) }
    public mutating func pause(at now: Date = Date()) { accumulated = elapsed(at: now); resumedAt = nil }
    public mutating func resume(at now: Date = Date()) { if resumedAt == nil { resumedAt = now } }
}
