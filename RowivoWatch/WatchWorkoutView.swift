import SwiftUI
import WatchKit
import RowivoCore

enum WatchStyle {
    static let lime = Color(red: 0.84, green: 0.94, blue: 0.65)
    static let ink = Color(red: 0.07, green: 0.20, blue: 0.20)
}

private struct WatchFeedbackDraft: Identifiable {
    var snapshot: WatchSnapshot
    var id: UUID { snapshot.controlToken }
}

struct WatchWorkoutView: View {
    @Environment(WatchCompanionModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var feedback: WatchFeedbackDraft?
    @State private var confirmingStart = false
    @State private var confirmingLocalDiscard = false
    @State private var startSnapshot: WatchSnapshot?
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ScrollView {
                    VStack(spacing: 14) {
                        if model.saved { Label("Session saved", systemImage: "checkmark.circle.fill").foregroundStyle(WatchStyle.lime) }
                        if let snapshot = model.snapshot {
                            if let workout = snapshot.workout {
                                workoutContent(workout, snapshot: snapshot, now: timeline.date)
                            } else {
                                Image(systemName: "figure.rower").font(.largeTitle).foregroundStyle(WatchStyle.lime)
                                Text(snapshot.availability == .noProfile ? "Set up Rowivo on your iPhone" : "Add your next workout on iPhone")
                                    .font(.headline).multilineTextAlignment(.center)
                            }
                        } else {
                            Image(systemName: "iphone.and.arrow.forward").font(.largeTitle).foregroundStyle(WatchStyle.lime)
                            Text("Open Rowivo on your iPhone").font(.headline).multilineTextAlignment(.center)
                            Text("Your next workout will appear here.").font(.footnote).foregroundStyle(.secondary)
                        }
                        if !model.isLive(at: timeline.date) {
                            Label("iPhone connection needed", systemImage: "iphone.slash").font(.footnote).foregroundStyle(.orange)
                                .accessibilityIdentifier("watch.offline")
                            Text("Open Rowivo on your iPhone and keep it nearby.").font(.footnote).foregroundStyle(.secondary)
                            if model.workoutRuntime.isRunning {
                                Button("Stop Watch recording") { confirmingLocalDiscard = true }
                            }
                        }
                        if !model.workoutRuntime.enabled {
                            Button("Enable workout mode") { Task { await model.enableWorkoutMode() } }
                            Text("Keeps Rowivo active during rowing and saves the Watch workout to Apple Health when you save your session.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if let failure = model.workoutRuntime.failure { Text(failure).font(.footnote).foregroundStyle(.orange) }
                        if let error = model.errorMessage { Text(error).font(.footnote).foregroundStyle(.orange).accessibilityIdentifier("watch.error") }
                        if model.isPending { ProgressView("Waiting for iPhone…") }
                    }.padding(.horizontal, 8).padding(.bottom, 16)
                }
                // Return to the confirmation at the top after dismissing saved feedback.
                .id(model.saved)
            }
            .navigationTitle("Rowivo")
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { model.refresh() }
                    .foregroundStyle(WatchStyle.ink)
                    .disabled(model.isPending).accessibilityIdentifier("watch.refresh")
            } }
            .alert("Start another session?", isPresented: $confirmingStart, presenting: startSnapshot) { snapshot in
                Button("Cancel", role: .cancel) { }
                Button("Start anyway") {
                    model.perform(.start, expected: snapshot, acknowledgingRecentTraining: true)
                }
            } message: { _ in
                Text("You trained today or yesterday. Take a moment to decide whether you want to train again.")
            }
            .confirmationDialog("Stop Watch recording?", isPresented: $confirmingLocalDiscard, titleVisibility: .visible) {
                Button("Discard Watch recording", role: .destructive) { model.workoutRuntime.discardLocalWorkout() }
            } message: {
                Text("Discard only the Apple Health recording on this Watch. Your Rowivo session continues on iPhone; finish it there.")
            }
            .sheet(item: $feedback) { draft in WatchFeedbackView(snapshot: draft.snapshot) }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            model.foreground()
            while !Task.isCancelled {
                model.refresh()
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
        .onChange(of: model.snapshot?.clock?.resumedAt) { _, resumed in
            if resumed != nil, scenePhase == .active { model.foreground() }
        }
        .onChange(of: model.snapshot?.clock == nil) { _, ended in
            if ended { feedback = nil }
            else if scenePhase == .active { model.foreground() }
        }
    }

    @ViewBuilder private func workoutContent(_ workout: Workout, snapshot: WatchSnapshot, now: Date) -> some View {
        let live = model.isLive(at: now)
        let elapsed = snapshot.elapsed(at: now)
        let segment = workout.segment(at: Double(elapsed))
        Text(workout.displayName).font(.headline).multilineTextAlignment(.center).accessibilityIdentifier("watch.workout")
        if let clock = snapshot.clock {
            Text(live ? (clock.resumedAt == nil ? "Paused" : "Rowing") : "Timer continues offline")
                .font(.caption).foregroundStyle(WatchStyle.lime)
            Text(clockText(segment?.remaining ?? 0)).font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1).accessibilityIdentifier("watch.remaining")
            Text(segment.map { localized(workout.segments[$0.index].kind.rawValue) } ?? localized("Session complete"))
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Whole workout").font(.caption2).foregroundStyle(.secondary)
            ProgressView(value: Double(elapsed), total: Double(workout.totalSeconds)).tint(WatchStyle.lime)
            HStack {
                VStack { Text(clockText(elapsed)).monospacedDigit(); Text("Elapsed").font(.caption2).foregroundStyle(.secondary) }
                Spacer()
                VStack { Text(clockText(workout.totalSeconds - elapsed)).monospacedDigit(); Text("Remaining").font(.caption2).foregroundStyle(.secondary) }
            }.font(.caption)
            if let metrics = snapshot.metrics {
                let fresh = live && clock.resumedAt != nil && metrics.isFresh(at: now)
                VStack(spacing: 8) {
                    Text(fresh ? "Rower live" : "Last device values").font(.caption2).foregroundStyle(.secondary)
                    HStack {
                        metric(metrics.distance.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—", label: "Meters")
                        Spacer()
                        metric(fresh ? metrics.pace.map { clockText(Int($0)) } ?? "—" : "—", label: "/500 m")
                    }
                    HStack {
                        metric(fresh ? metrics.strokeRate.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—" : "—", label: "spm")
                        Spacer()
                        metric(fresh ? metrics.heartRate.map(String.init) ?? "—" : "—", label: "bpm · rower")
                    }
                }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
            }
            if elapsed < workout.totalSeconds {
                Button(clock.resumedAt == nil ? "Continue rowing" : "Pause session", systemImage: clock.resumedAt == nil ? "play.fill" : "pause.fill") {
                    model.perform(clock.resumedAt == nil ? .resume : .pause)
                }.buttonStyle(.borderedProminent).tint(WatchStyle.lime).foregroundStyle(WatchStyle.ink)
                    .disabled(!live || model.isPending).accessibilityIdentifier(clock.resumedAt == nil ? "watch.resume" : "watch.pause")
            }
            Button("Finish session", systemImage: "stop.fill") {
                model.perform(.pause) { if let paused = model.snapshot { feedback = WatchFeedbackDraft(snapshot: paused) } }
            }.disabled(!live || model.isPending).accessibilityIdentifier("watch.finish")

        } else {
            Text(durationText(workout.totalSeconds)).font(.title2).foregroundStyle(WatchStyle.lime)
            Text("Planned duration").font(.caption).foregroundStyle(.secondary)
            if [.ready, .restDay].contains(snapshot.availability) {
                if snapshot.availability == .restDay {
                    Text("You trained recently.").font(.footnote).foregroundStyle(.secondary)
                }
                Button("Start rowing", systemImage: "play.fill") {
                    if snapshot.availability == .restDay {
                        startSnapshot = snapshot; confirmingStart = true
                    } else { model.perform(.start, expected: snapshot) }
                }
                    .buttonStyle(.borderedProminent).tint(WatchStyle.lime).foregroundStyle(WatchStyle.ink)
                    .disabled(!live || model.isPending).accessibilityIdentifier("watch.start")
            } else {
                Text(availabilityText(snapshot)).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            Text("Keep your iPhone nearby. It records your session and connects to the rower.").font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func metric(_ value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(value).font(.headline).monospacedDigit(); Text(label).font(.caption2).foregroundStyle(.secondary) }
    }
    private func availabilityText(_ snapshot: WatchSnapshot) -> String {
        switch snapshot.availability {
        case .checkIn: String(localized: "Complete your check-in on iPhone before rowing.")
        case .restDay: String(localized: "You trained recently.")
        case .busy: String(localized: "Your iPhone is working with your training data. Try again shortly.")
        default: String(localized: "Open Rowivo on your iPhone")
        }
    }
}

private struct WatchFeedbackView: View {
    @Environment(WatchCompanionModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let snapshot: WatchSnapshot
    @State private var effort = 2
    @State private var discomfort = false
    @State private var note = ""
    @State private var confirmingDelete = false
    private var controlsUnavailable: Bool {
        model.isPending || !model.isLive() || snapshot.controlToken != model.snapshot?.controlToken
    }
    private func effortDescription(_ value: Int) -> String {
        localized(["Very easy", "Comfortable", "Moderate", "Hard", "Very hard"][value - 1])
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(durationText(max(1, snapshot.elapsed(at: snapshot.generatedAt)))).font(.title2).foregroundStyle(WatchStyle.lime)
                    Text("Actual duration").font(.caption).foregroundStyle(.secondary)
                    if let workout = snapshot.workout, snapshot.elapsed(at: snapshot.generatedAt) < workout.totalSeconds {
                        Text("This will be saved as a partial session. The planned workout stays open.").font(.footnote).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 8) {
                        Text("Effort").font(.headline)
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { value in
                                Button { effort = value } label: {
                                    Text("\(value)").font(.system(.body, design: .rounded).weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundStyle(effort == value ? WatchStyle.ink : .white)
                                        .background(effort == value ? WatchStyle.lime : .white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                                        .contentShape(RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain)
                                    .accessibilityLabel("\(value)/5 · " + effortDescription(value))
                                    .accessibilityAddTraits(effort == value ? .isSelected : [])
                                    .accessibilityIdentifier("watch.effort.\(value)")
                            }
                        }
                        Text(effortDescription(effort)).font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("watch.effort.description")
                    }.disabled(model.isPending)
                    Toggle("I felt pain or discomfort", isOn: $discomfort).accessibilityIdentifier("watch.discomfort")
                    TextField("Note (optional)", text: $note).accessibilityIdentifier("watch.note")
                    if snapshot.controlToken != model.snapshot?.controlToken {
                        Text("The session changed on your iPhone. Reopen this feedback to continue.").font(.footnote).foregroundStyle(.orange)
                    }
                    if let error = model.errorMessage { Text(error).font(.footnote).foregroundStyle(.orange) }
                    Button("Save session") {
                        model.perform(.save, expected: snapshot, effort: effort, discomfort: discomfort, note: note) { dismiss() }
                    }.buttonStyle(.borderedProminent).tint(WatchStyle.lime).foregroundStyle(WatchStyle.ink)
                        .disabled(controlsUnavailable || note.count > 2_000)
                        .accessibilityIdentifier("watch.save")
                    Text("You can edit all details later on your iPhone.").font(.footnote).foregroundStyle(.secondary)
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Text("Delete recording").frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                    }
                        .buttonStyle(.plain).font(.footnote).foregroundStyle(.red)
                        .disabled(controlsUnavailable).accessibilityIdentifier("watch.discard")
                }.padding(.horizontal, 8).padding(.bottom, 12)
            }.navigationTitle("Your reflection")
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("Back", systemImage: "chevron.left") { dismiss() }
                        .labelStyle(.iconOnly).foregroundStyle(WatchStyle.ink)
                        .disabled(model.isPending).accessibilityIdentifier("watch.feedback.back")
                } }
                .confirmationDialog("Delete this recording?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete recording", role: .destructive) {
                        model.perform(.discard, expected: snapshot) { dismiss() }
                    }.disabled(controlsUnavailable).accessibilityIdentifier("watch.discard.confirm")
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The current recording and its device data will be deleted. Your planned workout stays available.")
                }
        }.interactiveDismissDisabled(model.isPending)
    }
}
