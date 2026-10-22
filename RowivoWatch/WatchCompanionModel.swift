import Foundation
import Observation
import RowivoCore
import HealthKit
import WatchKit

@MainActor @Observable final class WatchCompanionModel {
    let transport = WatchTransport()
    private(set) var snapshot: WatchSnapshot?
    private(set) var lastLiveContact: Date?
    private(set) var isPending = false
    private(set) var saved = false
    var errorMessage: String?
    let workoutRuntime = WatchWorkoutRuntime()
    @ObservationIgnored private var pulse: Task<Void, Never>?
    @ObservationIgnored private var phaseIdentity: String?
    func foreground() {
        refresh()
        workoutRuntime.synchronize(snapshot, mayStart: true)
    }
    func enableWorkoutMode() async {
        await workoutRuntime.authorize()
        workoutRuntime.synchronize(snapshot, mayStart: true)
    }
    @ObservationIgnored private var pendingID: UUID?
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var refreshID: UUID?
    @ObservationIgnored private var refreshTimeout: Task<Void, Never>?
    @ObservationIgnored private var cachedToken: UUID?
    @ObservationIgnored private let cacheKey = "rowivo.watch.snapshot.v1"
    #if DEBUG
    @ObservationIgnored private var preview = false
    #endif

    init() {
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--watch-preview"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
            preview = true
            let mode = ProcessInfo.processInfo.arguments[index + 1]
            let workout = Workout(kind: .intervals, segments: [.init(kind: .warmup, seconds: 180), .init(kind: .work, seconds: 300), .init(kind: .rest, seconds: 60), .init(kind: .work, seconds: 300), .init(kind: .cooldown, seconds: 180)])
            var clock = WorkoutClock(workoutID: workout.id, now: Date().addingTimeInterval(-253))
            if mode == "paused" { clock.pause() }
            snapshot = WatchSnapshot(controlToken: UUID(), availability: mode == "recent" ? .restDay : .ready, workout: workout,
                                     clock: ["ready", "recent"].contains(mode) ? nil : clock,
                                     metrics: ["ready", "recent"].contains(mode) ? nil : WatchMetrics(snapshot: .init(date: Date(), general: .init(elapsed: 253, distance: 820), pace: 145, strokeRate: 24, watts: 114, heartRate: 132), distance: 820))
            if mode == "empty" { snapshot = .init(controlToken: UUID(), availability: .noProfile) }
            lastLiveContact = mode == "offline" ? nil : Date()
            return
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: cacheKey), let value = try? WatchWire.decode(WatchSnapshot.self, from: data),
           (try? value.validate()) != nil { snapshot = value; cachedToken = value.controlToken }
        transport.onSnapshot = { [weak self] data in
            guard let value = try? WatchWire.decode(WatchSnapshot.self, from: data) else { return }
            self?.apply(value)
            // Cached application contexts must not impersonate a live reply.
            if abs(value.generatedAt.timeIntervalSinceNow) < 5 { self?.lastLiveContact = Date() }
        }
        transport.onStatus = { [weak self] in self?.refresh() }
        transport.activate()
        pulse = Task { [weak self] in
            var ticks = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                guard let value = self.snapshot, let workout = value.workout, let clock = value.clock else {
                    self.phaseIdentity = nil; continue
                }
                let index = workout.segment(at: Double(value.elapsed(at: Date())))?.index
                let key = workout.id.uuidString + ":" + String(index ?? -1)
                if let previous = self.phaseIdentity, previous != key, clock.resumedAt != nil {
                    WKInterfaceDevice.current().play(index == nil ? .success : .notification)
                }
                self.phaseIdentity = key
                self.workoutRuntime.synchronize(value, mayStart: WKExtension.shared().applicationState == .active)
                ticks += 1
                if self.workoutRuntime.isRunning, ticks % 5 == 0 { self.refresh() }
            }
        }
    }

    func isLive(at date: Date = Date()) -> Bool {
        #if DEBUG
        if preview { return lastLiveContact != nil }
        #endif
        return transport.isReachable && lastLiveContact.map { (0...12).contains(date.timeIntervalSince($0)) } == true
    }

    func refresh() {
        #if DEBUG
        if preview { return }
        #endif
        guard !isPending, refreshID == nil, transport.isReachable else { return }
        let command = WatchCommand(action: .refresh)
        guard let data = try? WatchWire.encode(command) else { return }
        refreshID = command.id
        refreshTimeout?.cancel()
        refreshTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, self?.refreshID == command.id else { return }
            self?.refreshID = nil
        }
        transport.send(data) { [weak self] result in
            guard let self else { return }
            guard self.refreshID == command.id else { return }
            self.refreshTimeout?.cancel(); self.refreshID = nil
            if case .success(let data) = result, let reply = try? WatchWire.decode(WatchReply.self, from: data),
               reply.requestID == command.id, reply.result == .ok, (try? reply.snapshot.validate()) != nil {
                self.apply(reply.snapshot); self.lastLiveContact = Date()
            }
        }
    }

    func perform(_ action: WatchCommand.Action, expected: WatchSnapshot? = nil, effort: Int? = nil,
                 discomfort: Bool? = nil, note: String? = nil, acknowledgingRecentTraining: Bool = false, onSuccess: @escaping @MainActor () -> Void = {}) {
        guard !isPending, isLive(), let current = expected ?? snapshot else {
            errorMessage = String(localized: "Reconnect to your iPhone before changing this session."); return
        }
        let command = WatchCommand(action: action, snapshot: current, effort: effort, discomfort: discomfort, note: note, acknowledgingRecentTraining: acknowledgingRecentTraining)
        guard let data = try? WatchWire.encode(command) else { return }
        isPending = true; pendingID = command.id; errorMessage = nil; saved = false
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, self.pendingID == command.id else { return }
            self.pendingID = nil; self.isPending = false; self.lastLiveContact = nil
            self.errorMessage = String(localized: "No confirmation yet. Check the session on your iPhone before trying again.")
        }
        transport.send(data) { [weak self] result in
            guard let self else { return }
            let isCurrent = self.pendingID == command.id
            if isCurrent { self.timeout?.cancel(); self.pendingID = nil; self.isPending = false }
            guard case .success(let data) = result, let reply = try? WatchWire.decode(WatchReply.self, from: data),
                  reply.requestID == command.id, (try? reply.snapshot.validate()) != nil else {
                if isCurrent {
                    self.lastLiveContact = nil
                    self.errorMessage = String(localized: "No confirmation yet. Check the session on your iPhone before trying again.")
                }
                return
            }
            self.apply(reply.snapshot); self.lastLiveContact = Date()
            if reply.result == .ok {
                if action == .save { self.saved = true }
                if isCurrent { onSuccess() }
            } else if isCurrent {
                switch reply.result {
                case .stale: self.errorMessage = String(localized: "The session changed on your iPhone. Review the updated state and try again.")
                case .unavailable: self.errorMessage = String(localized: "This action is not available. Check Rowivo on your iPhone.")
                case .invalid: self.errorMessage = String(localized: "Check your feedback or update Rowivo on both devices.")
                case .failed: self.errorMessage = String(localized: "Your iPhone could not save the change. Please try again.")
                case .ok: break
                }
            }
        }
    }

    private func apply(_ value: WatchSnapshot) {
        guard (try? value.validate()) != nil,
              snapshot.map({ value.generatedAt >= $0.generatedAt }) != false else { return }
        snapshot = value
        workoutRuntime.synchronize(value, mayStart: false)
        if value.workout == nil {
            UserDefaults.standard.removeObject(forKey: cacheKey); cachedToken = nil
        } else if cachedToken != value.controlToken, let data = try? WatchWire.encode(value) {
            UserDefaults.standard.set(data, forKey: cacheKey); cachedToken = value.controlToken
        }
    }
}

/// A real indoor rowing session gives watchOS the native workout lifecycle.
/// Health writes are opt-in; saving/discarding follows the confirmed phone outcome.
@MainActor @Observable final class WatchWorkoutRuntime: NSObject, HKWorkoutSessionDelegate {
    private(set) var enabled = UserDefaults.standard.bool(forKey: "rowivo.watch.health")
    private(set) var isRunning = false
    var failure: String?
    @ObservationIgnored private let health = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var workoutID: UUID?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var ended = false
    @ObservationIgnored private var endedAt: Date?
    @ObservationIgnored private var finishing = false
    @ObservationIgnored private var rejectedID: UUID?

    func authorize() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await health.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
            enabled = health.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
            UserDefaults.standard.set(enabled, forKey: "rowivo.watch.health")
            if !enabled { failure = String(localized: "Allow workouts in Health to enable workout mode.") }
        } catch { failure = error.localizedDescription }
    }

    func synchronize(_ snapshot: WatchSnapshot?, mayStart: Bool) {
        guard let snapshot, !finishing else { return }
        if snapshot.clock == nil { rejectedID = nil }
        if let session {
            if snapshot.clock?.workoutID != workoutID {
                let save = snapshot.lastSavedWorkoutID == workoutID &&
                    snapshot.lastSavedAt.map { $0 >= (startedAt ?? .distantFuture) } == true
                finish(save: save); return
            }
            if let workout = snapshot.workout, snapshot.elapsed(at: Date()) >= workout.totalSeconds {
                if !ended { ended = true; endedAt = Date(); isRunning = false; session.end() }
            } else if !ended {
                if snapshot.clock?.resumedAt == nil, session.state == .running { session.pause() }
                else if snapshot.clock?.resumedAt != nil, session.state == .paused { session.resume() }
            }
            return
        }
        guard mayStart, enabled, let clock = snapshot.clock, clock.resumedAt != nil, let workout = snapshot.workout,
              snapshot.elapsed(at: Date()) < workout.totalSeconds, rejectedID != workout.id else { return }
        do {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .rowing; configuration.locationType = .indoor
            let session = try HKWorkoutSession(healthStore: health, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            // Only workout authorization is requested. No access to the user's health history.
            self.session = session; self.builder = builder; workoutID = workout.id
            startedAt = Date(); ended = false; endedAt = nil; failure = nil
            session.delegate = self
            session.startActivity(with: startedAt)
            builder.beginCollection(withStart: startedAt!) { @Sendable [weak self] success, error in
                guard !success else { return }
                let message = error?.localizedDescription
                Task { @MainActor in
                    guard let self, self.session === session else { return }
                    self.failure = message ?? String(localized: "Could not start the Watch workout.")
                    self.rejectedID = self.workoutID; session.end(); builder.discardWorkout()
                    self.isRunning = false; self.clear()
                }
            }
            isRunning = true
            if clock.resumedAt == nil { session.pause() }
        } catch { rejectedID = workout.id; failure = error.localizedDescription }
    }

    func discardLocalWorkout() {
        rejectedID = workoutID
        finish(save: false)
    }
    private func finish(save: Bool) {
        guard let session, let builder else { return }
        finishing = true; isRunning = false
        if !ended { session.end() }
        builder.endCollection(withEnd: endedAt ?? Date()) { @Sendable [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if save, error == nil {
                    builder.finishWorkout { @Sendable [weak self] _, error in
                        Task { @MainActor in
                            if let error { self?.failure = error.localizedDescription }
                            self?.clear()
                        }
                    }
                } else { builder.discardWorkout(); self.clear() }
            }
        }
    }
    private func clear() { session = nil; builder = nil; workoutID = nil; startedAt = nil; ended = false; finishing = false }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                   from fromState: HKWorkoutSessionState, date: Date) { }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        let identifier = ObjectIdentifier(workoutSession)
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == identifier else { return }
            self.failure = message; self.rejectedID = self.workoutID
            self.builder?.discardWorkout(); self.isRunning = false; self.clear()
        }
    }
}
