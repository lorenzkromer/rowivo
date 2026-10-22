import SwiftUI
import AudioToolbox
import RowivoCore

struct ActiveWorkoutView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var workout: Workout
    @State private var feedback = false
    @State private var confirmEnd = false
    @State private var recordedSeconds = 0
    @State private var device = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let elapsed = store.state.clock?.elapsed(at: timeline.date) ?? 0
                let phase = workout.segment(at: elapsed)
                let paused = store.state.clock?.resumedAt == nil
                let hasRower = store.rower.isConnected || store.rowerRecording != nil
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 9) {
                            Eyebrow(text: paused ? "Paused" : "You showed up").foregroundStyle(RowivoStyle.teal)
                            Text(phase.map { localized(workout.segments[$0.index].kind.rawValue) } ?? localized("Session complete"))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text(workout.displayName).foregroundStyle(RowivoStyle.muted)
                        }.padding(.top, 24)
                        HStack(spacing: 24) {
                            WorkoutRing(progress: min(1, elapsed / Double(workout.totalSeconds)),
                                        value: clockText(min(Int(elapsed), workout.totalSeconds)), label: "Whole workout", color: RowivoStyle.teal)
                            WorkoutRing(progress: phase.map { 1 - Double($0.remaining) / Double(workout.segments[$0.index].seconds) } ?? 1,
                                        value: clockText(phase?.remaining ?? 0), label: "Current phase", color: RowivoStyle.clay)
                                .accessibilityIdentifier("workout.timer")
                        }.padding(.vertical, 8)
                        if store.state.automaticallyPaused == true {
                            Text("Auto-paused · row to continue").font(.subheadline).foregroundStyle(RowivoStyle.teal)
                        }
                        HStack {
                            Metric(value: clockText(workout.totalSeconds), label: "Planned duration")
                            Metric(value: clockText(max(0, workout.totalSeconds - Int(elapsed))), label: "Remaining")
                        }.padding(.horizontal, 30)
                        if hasRower { RowerLivePanel() }
                        Surface {
                            HStack(spacing: 14) {
                                Image(systemName: "wind").font(.title2).foregroundStyle(RowivoStyle.teal)
                                Text(localized(phase.map { workout.segments[$0.index].kind == .rest } == true ? "Pause, relax your grip and take a breath." : "Keep it comfortable. Smooth beats fast."))
                                    .font(.subheadline).lineSpacing(3)
                            }
                        }
                    }.padding(25)
                }.rowivoScreen()
                    .rowivoBottomBar {
                        VStack(spacing: 12) {
                        if phase == nil {
                            Button("Finish and reflect") {
                                recordedSeconds = workout.totalSeconds
                                store.prepareReflection()
                                feedback = true
                            }.buttonStyle(PrimaryButton()).accessibilityIdentifier("workout.finish")
                        } else {
                            Button { store.toggleTimer() } label: {
                                Label(localized(paused ? "Continue rowing" : "Pause session"), systemImage: paused ? "play.fill" : "pause.fill")
                            }.buttonStyle(PrimaryButton()).accessibilityIdentifier("workout.pause")
                            Button("End session early") {
                                recordedSeconds = max(1, min(workout.totalSeconds, Int(elapsed)))
                                store.prepareReflection()
                                confirmEnd = true
                            }.font(.subheadline).foregroundStyle(RowivoStyle.muted).accessibilityIdentifier("workout.end")
                        }
                        }.padding(.horizontal, 22).padding(.vertical, 12)
                    }
                    .onChange(of: phase?.index) { previous, current in
                        guard previous != nil, previous != current, !paused else { return }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        if store.workoutPreferences.phaseSounds { AudioServicesPlaySystemSound(1057) }
                    }
            }
            .navigationTitle("Rowivo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.down") }.accessibilityLabel("Back to app") }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { device = true } label: { Image(systemName: "antenna.radiowaves.left.and.right") }
                        .accessibilityLabel("Connect your rower").accessibilityIdentifier("pm5.open")
                }
            }
            .confirmationDialog("End this session?", isPresented: $confirmEnd, titleVisibility: .visible) {
                Button("Save partial session") { feedback = true }
                Button("Discard session", role: .destructive) { store.discardTimer() }
                Button("Keep rowing", role: .cancel) { }
            } message: { Text("A partial session is saved in your history. The planned workout stays open.") }
            .sheet(isPresented: $feedback) { WorkoutFeedbackView(workout: workout, seconds: recordedSeconds, manual: false) }
            .sheet(isPresented: $device) { RowerDeviceView() }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: scenePhase) { _, phase in UIApplication.shared.isIdleTimerDisabled = phase == .active }
        }.interactiveDismissDisabled()
    }
}

struct WorkoutFeedbackView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var workout: Workout
    var seconds: Int
    var manual: Bool
    @State private var effort = 2
    @State private var discomfort = false
    @State private var note = ""
    @State private var actualMinutes = 0
    @State private var actualSeconds = 0
    @State private var trainedAt = Date()
    @State private var saveError: String?
    private var duration: Int { manual ? actualMinutes * 60 + actualSeconds : seconds }
    private var effortLabel: String {
        localized(["Very easy", "Comfortable", "Moderate", "Hard", "Very hard"][effort - 1])
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Every session counts").foregroundStyle(RowivoStyle.teal)
                        Text("How did that feel?").font(.system(size: 31, weight: .bold, design: .rounded))
                        Text("Save the time you trained and how it felt.").foregroundStyle(RowivoStyle.muted)
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            if manual {
                                DatePicker("Workout date", selection: $trainedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact).accessibilityIdentifier("feedback.date")
                                Divider()
                                Text("Actual duration").font(.subheadline)
                                Text(durationText(duration)).font(.title2.bold()).accessibilityIdentifier("feedback.duration")
                                Stepper(value: $actualMinutes, in: 0...240) { LabeledContent("Minutes", value: actualMinutes.formatted()) }.accessibilityIdentifier("feedback.minutes")
                                Stepper(value: $actualSeconds, in: 0...59) { LabeledContent("Seconds", value: actualSeconds.formatted()) }.accessibilityIdentifier("feedback.seconds")
                            } else { Label(clockText(seconds), systemImage: "clock").font(.title3.monospacedDigit()) }
                            LabeledContent("Planned duration", value: durationText(workout.totalSeconds))
                                .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                            if !manual, let recording = store.rowerRecording, recording.hasMeasurements {
                                RowerRecordingSummary(recording: recording)
                            } else {
                                Text(localized(manual ? "Recorded by you. No sensor data is added." : "Timed with Rowivo. No device measurements were recorded."))
                                    .font(.caption).foregroundStyle(RowivoStyle.muted)
                            }
                            if duration < workout.totalSeconds {
                                Text("This will be saved as a partial session. The planned workout stays open.")
                                    .font(.caption).foregroundStyle(RowivoStyle.clay)
                            }
                        }
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack { Text("Effort").font(.headline); Spacer(); Text(effortLabel).font(.subheadline).foregroundStyle(RowivoStyle.muted) }
                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { value in
                                    Button { effort = value } label: {
                                        Text(value.formatted()).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                                            .background(effort == value ? RowivoStyle.lime : RowivoStyle.background, in: RoundedRectangle(cornerRadius: 13))
                                    }.buttonStyle(.plain).accessibilityLabel(localized(["Very easy", "Comfortable", "Moderate", "Hard", "Very hard"][value - 1]))
                                }
                            }
                            Toggle("I felt pain or discomfort", isOn: $discomfort).font(.subheadline).tint(RowivoStyle.teal)
                            if discomfort { Text("Pause training if discomfort persists and seek professional advice. We will ask you to check in before starting again.").font(.caption).foregroundStyle(RowivoStyle.clay) }
                        }
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Anything to remember?").font(.headline)
                            TextField("Energy, technique, how you felt…", text: $note, axis: .vertical)
                                .lineLimit(3...6).font(.subheadline).accessibilityIdentifier("feedback.note")
                        }
                    }
                    if let saveError { Text(saveError).foregroundStyle(RowivoStyle.clay) }
                    Button("Save session") {
                        if store.complete(workout, seconds: duration, effort: effort, discomfort: discomfort, note: note, manual: manual,
                                          trainedAt: manual ? trainedAt : nil) { dismiss() }
                        else { saveError = store.errorMessage ?? String(localized: "Could not save. Please try again."); store.errorMessage = nil }
                    }.buttonStyle(PrimaryButton()).disabled(!(1...14_400).contains(duration)).accessibilityIdentifier("feedback.save")
                }.padding(22)
            }.rowivoScreen().scrollDismissesKeyboard(.interactively)
                .navigationTitle("Your reflection").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onAppear { actualMinutes = seconds / 60; actualSeconds = seconds % 60 }
        }
    }
}

private struct WorkoutRing: View {
    var progress: Double
    var value: String
    var label: LocalizedStringKey
    var color: Color
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(color.opacity(0.12), lineWidth: 9)
                Circle().trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                Text(value).font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.6).lineLimit(1).padding(12)
            }.aspectRatio(1, contentMode: .fit)
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(color)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}
