import Foundation
import Observation
import RowivoCore

@MainActor @Observable final class PhoneWatchConnection {
    let transport = WatchTransport()
    @ObservationIgnored private weak var store: RowivoStore?
    @ObservationIgnored private var lastTelemetry = Date.distantPast
    @ObservationIgnored private var receipts: [UUID: WatchCommandResult] = [:]
    init(store: RowivoStore) {
        self.store = store
        transport.onStatus = { [weak self] in self?.publish() }
        transport.onRequest = { [weak self] data in
            guard let self, let store = self.store,
                  let command = try? WatchWire.decode(WatchCommand.self, from: data) else { return Data() }
            let result = self.receipts[command.id] ?? store.performWatchCommand(command)
            if command.action != .refresh {
                if self.receipts.count >= 32 { self.receipts.removeAll() }
                self.receipts[command.id] = result
            }
            return (try? WatchWire.encode(WatchReply(requestID: command.id, result: result, snapshot: store.watchSnapshot()))) ?? Data()
        }
        store.companionDidChange = { [weak self] in self?.publish() }
        store.companionTelemetryDidChange = { [weak self] in
            guard let self, Date().timeIntervalSince(self.lastTelemetry) >= 1 else { return }
            self.lastTelemetry = Date(); self.publish(background: false)
        }
        transport.activate()
    }
    func publish(background: Bool = true) {
        guard let store, let data = try? WatchWire.encode(store.watchSnapshot()) else { return }
        transport.publish(data, background: background)
    }
}

extension RowivoStore {
    func watchSnapshot(now: Date = Date()) -> WatchSnapshot {
        let availability: WatchAvailability
        if isDeletingData || isTransferringFiles { availability = .busy }
        else if state.profile == nil { availability = .noProfile }
        else if activeWorkout != nil { availability = .ready }
        else if nextWorkout == nil { availability = .noPlan }
        else if needsCheckIn { availability = .checkIn }
        else if requiresRecentTrainingConfirmation { availability = .restDay }
        else { availability = .ready }
        var metrics: WatchMetrics?
        if state.clock != nil, rower.isConnected, let snapshot = rower.latest, let recording = rowerRecording {
            metrics = WatchMetrics(snapshot: snapshot, distance: recording.measuredDistance)
        }
        var result = WatchSnapshot(controlToken: watchControlToken, availability: availability,
                             workout: activeWorkout ?? nextWorkout, clock: state.clock, metrics: metrics,
                             availableAt: availability == .restDay ? PlanEngine.availableDate(completions: state.completions) : nil,
                             generatedAt: now)
        let saved = state.completions.max { ($0.recordedAt ?? $0.date) < ($1.recordedAt ?? $1.date) }
        result.lastSavedWorkoutID = saved?.workoutID
        result.lastSavedAt = saved?.recordedAt
        return result
    }

    /// Commands name a desired action and an exact control state; delayed/repeated commands cannot toggle a later session.
    func performWatchCommand(_ command: WatchCommand, now: Date = Date()) -> WatchCommandResult {
        guard command.version == 1 else { return .invalid }
        if command.action == .refresh { return .ok }
        guard command.issuedAt.timeIntervalSinceReferenceDate.isFinite,
              abs(now.timeIntervalSince(command.issuedAt)) <= 30,
              command.controlToken == watchControlToken else { return .stale }
        guard !isDeletingData, !isTransferringFiles, state.profile != nil,
              let workout = activeWorkout ?? nextWorkout, command.workoutID == workout.id else { return .unavailable }
        switch command.action {
        case .refresh: return .ok
        case .start:
            guard state.clock == nil, canTrain,
                  !requiresRecentTrainingConfirmation || command.acknowledgesRecentTraining == true else { return .unavailable }
            start(workout, acknowledgingRecentTraining: command.acknowledgesRecentTraining == true, expectedControlToken: command.controlToken)
            return state.clock?.workoutID == workout.id ? .ok : .failed
        case .pause:
            guard state.clock != nil else { return .unavailable }
            prepareReflection()
            return state.clock?.resumedAt == nil ? .ok : .failed
        case .resume:
            guard let clock = state.clock, clock.resumedAt == nil,
                  clock.elapsed(at: now) < Double(workout.totalSeconds) else { return .unavailable }
            toggleTimer()
            return state.clock?.resumedAt != nil ? .ok : .failed
        case .discard:
            guard let clock = state.clock, clock.resumedAt == nil else { return .unavailable }
            discardTimer()
            return state.clock == nil ? .ok : .failed
        case .save:
            guard let clock = state.clock, clock.resumedAt == nil else { return .unavailable }
            guard let effort = command.effort, (1...5).contains(effort), let discomfort = command.discomfort,
                  (command.note?.count ?? 0) <= 2_000 else { return .invalid }
            let seconds = max(1, min(workout.totalSeconds, Int(clock.elapsed(at: now))))
            return complete(workout, seconds: seconds, effort: effort, discomfort: discomfort,
                            note: command.note ?? "", manual: false) ? .ok : .failed
        }
    }
}
