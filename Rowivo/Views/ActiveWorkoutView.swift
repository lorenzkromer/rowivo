import SwiftUI
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
                let hasPM5 = store.pm5.isConnected || store.pm5Recording != nil
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 9) {
                            Eyebrow(text: paused ? "Paused" : "You showed up").foregroundStyle(RowivoStyle.teal)
                            Text(phase.map { localized(workout.segments[$0.index].kind.rawValue) } ?? localized("Session complete"))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text(workout.displayName).foregroundStyle(RowivoStyle.muted)
                        }.padding(.top, 24)
                        ZStack {
                            Circle().stroke(RowivoStyle.pale, lineWidth: 12)
                            Circle().trim(from: 0, to: min(1, elapsed / Double(workout.totalSeconds)))
                                .stroke(RowivoStyle.teal, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                            VStack(spacing: 12) {
                                Image(systemName: phase == nil ? "checkmark" : "figure.rower").font(.system(size: 38, weight: .light))
                                Text(clockText(phase?.remaining ?? 0)).font(.system(size: hasPM5 ? 42 : 58, weight: .medium, design: .rounded)).monospacedDigit()
                                    .contentTransition(.numericText()).accessibilityIdentifier("workout.timer")
                                Text("In this segment").font(.subheadline).foregroundStyle(RowivoStyle.muted)
                            }
                        }.frame(width: hasPM5 ? 195 : 275, height: hasPM5 ? 195 : 275).padding(.vertical, 8)
                        HStack {
                            Metric(value: clockText(min(Int(elapsed), workout.totalSeconds)), label: "Elapsed")
                            Metric(value: clockText(max(0, workout.totalSeconds - Int(elapsed))), label: "Remaining")
                        }.padding(.horizontal, 30)
                        if hasPM5 { PM5LivePanel() }
                        Surface {
                            HStack(spacing: 14) {
                                Image(systemName: "wind").font(.title2).foregroundStyle(RowivoStyle.teal)
                                Text(localized(phase.map { workout.segments[$0.index].kind == .rest } == true ? "Pause, relax your grip and take a breath." : "Keep it comfortable. Smooth beats fast."))
                                    .font(.subheadline).lineSpacing(3)
                            }
                        }
                        if phase == nil {
                            Button("Finish and reflect") {
                                recordedSeconds = workout.totalSeconds
                                if store.state.clock?.resumedAt != nil { store.toggleTimer() }
                                feedback = true
                            }.buttonStyle(PrimaryButton()).accessibilityIdentifier("workout.finish")
                        } else {
                            Button { store.toggleTimer() } label: {
                                Label(localized(paused ? "Continue rowing" : "Pause session"), systemImage: paused ? "play.fill" : "pause.fill")
                            }.buttonStyle(PrimaryButton()).accessibilityIdentifier("workout.pause")
                            Button("End session early") {
                                recordedSeconds = max(1, min(workout.totalSeconds, Int(elapsed)))
                                if store.state.clock?.resumedAt != nil { store.toggleTimer() }
                                confirmEnd = true
                            }.font(.subheadline).foregroundStyle(RowivoStyle.muted).accessibilityIdentifier("workout.end")
                        }
                    }.padding(25)
                }.rowivoScreen()
            }
            .navigationTitle("Rowivo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.down") }.accessibilityLabel("Back to app") }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { device = true } label: { Image(systemName: "antenna.radiowaves.left.and.right") }
                        .accessibilityLabel("Connect your PM5").accessibilityIdentifier("pm5.open")
                }
            }
            .confirmationDialog("End this session?", isPresented: $confirmEnd, titleVisibility: .visible) {
                Button("Save partial session") { feedback = true }
                Button("Discard session", role: .destructive) { store.discardTimer() }
                Button("Keep rowing", role: .cancel) { }
            } message: { Text("A partial session is saved in your history. The planned workout stays open.") }
            .sheet(isPresented: $feedback) { WorkoutFeedbackView(workout: workout, seconds: recordedSeconds, manual: false) }
            .sheet(isPresented: $device) { PM5DeviceView() }
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
                            if !manual, let recording = store.pm5Recording, recording.hasMeasurements {
                                PM5RecordingSummary(recording: recording)
                            } else {
                                Text(localized(manual ? "Recorded by you. No sensor data is added." : "Timed with Rowivo. No PM5 measurements were recorded."))
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
                    Button("Save session") {
                        if store.complete(workout, seconds: duration, effort: effort, discomfort: discomfort, note: note, manual: manual,
                                          trainedAt: manual ? trainedAt : nil) { dismiss() }
                    }.buttonStyle(PrimaryButton()).disabled(!(1...14_400).contains(duration)).accessibilityIdentifier("feedback.save")
                }.padding(22)
            }.rowivoScreen().scrollDismissesKeyboard(.interactively)
                .navigationTitle("Your reflection").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onAppear { actualMinutes = seconds / 60; actualSeconds = seconds % 60 }
        }
    }
}
