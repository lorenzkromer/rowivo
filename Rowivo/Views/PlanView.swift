import SwiftUI
import RowivoCore

struct PlanView: View {
    @Environment(RowivoStore.self) private var store
    @State private var editor: WorkoutEditorRequest?
    @State private var organizing = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Training overview").font(.system(size: 33, weight: .bold, design: .rounded)).tracking(-0.8)
                        Text("Plan your workouts here. Recorded sessions show what you actually did.").foregroundStyle(RowivoStyle.muted).font(.subheadline).lineSpacing(3)
                    }
                    if store.state.clock != nil {
                        Label("Finish the active workout before editing your plan.", systemImage: "pause.circle").font(.subheadline).foregroundStyle(RowivoStyle.muted)
                    }
                    if let plan = store.state.plan {
                        if plan.blocks.isEmpty {
                            Surface {
                                VStack(alignment: .leading, spacing: 15) {
                                    Image(systemName: "square.and.pencil").font(.largeTitle).foregroundStyle(RowivoStyle.teal)
                                    Text("Build your first workout").font(.title2.bold())
                                    Text("Choose a name, add rowing and rest steps, then set their duration.").foregroundStyle(RowivoStyle.muted)
                                    Button("Create workout") { newWorkout() }.buttonStyle(PrimaryButton()).accessibilityIdentifier("plan.first-add")
                                }
                            }
                        }
                        ForEach(Array(plan.blocks.enumerated()), id: \.element.id) { index, block in
                            Surface {
                                VStack(alignment: .leading, spacing: 18) {
                                    HStack {
                                        Text(blockText(block.week)).font(.headline)
                                        Spacer()
                                        if block.id == store.currentBlock?.id {
                                            Text("Current").font(.caption.weight(.semibold)).padding(.horizontal, 11).padding(.vertical, 7).background(RowivoStyle.lime, in: Capsule())
                                        }
                                        Menu {
                                            Button("Add workout") { newWorkout(in: block.id) }
                                            Button("Move block up") { store.moveBlock(block.id, by: -1) }.disabled(index == 0)
                                            Button("Move block down") { store.moveBlock(block.id, by: 1) }.disabled(index == plan.blocks.count - 1)
                                            if block.workouts.isEmpty { Button("Delete empty block", role: .destructive) { store.deleteEmptyBlock(block.id) } }
                                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle()) }
                                        .disabled(store.state.clock != nil).accessibilityLabel("Block options")
                                    }
                                    VStack(spacing: 0) {
                                        ForEach(Array(block.workouts.enumerated()), id: \.element.id) { index, workout in
                                            NavigationLink { WorkoutDetailView(workout: workout) } label: {
                                                WorkoutRow(workout: workout, number: index + 1,
                                                           recordings: store.recordings(for: workout.id))
                                            }.buttonStyle(WorkoutRowButtonStyle())
                                                .accessibilityIdentifier("plan.workout.\(workout.id.uuidString)")
                                            if index < block.workouts.count - 1 { Divider().padding(.leading, 57) }
                                        }
                                    }
                                    if block.workouts.isEmpty {
                                        Button("Add workout") { newWorkout(in: block.id) }.disabled(store.state.clock != nil)
                                    }
                                }
                            }
                        }
                    }
                }.padding(22)
            }.rowivoScreen().navigationTitle("Plan").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add workout", systemImage: "plus") { newWorkout() }
                            .disabled(store.state.clock != nil).accessibilityIdentifier("plan.add")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Add block", systemImage: "square.stack.3d.up.badge.a") { store.addBlock() }
                            Button("Organize plan", systemImage: "arrow.up.arrow.down") { organizing = true }
                        } label: { Image(systemName: "ellipsis") }
                        .disabled(store.state.clock != nil).accessibilityLabel("Plan options").accessibilityIdentifier("plan.options")
                    }
                }
                .sheet(item: $editor) { WorkoutEditorView(request: $0) }
                .sheet(isPresented: $organizing) { PlanOrderView() }
        }
    }
    private func newWorkout(in blockID: UUID? = nil) {
        guard let plan = store.state.plan else { return }
        editor = .new(plan: plan, minutes: store.state.profile?.sessionMinutes ?? 30,
                      blockID: blockID ?? store.currentBlock?.id ?? plan.blocks.last?.id)
    }
}

struct WorkoutRow: View {
    var workout: Workout
    var number: Int
    var recordings: [WorkoutCompletion]
    private var complete: Bool { recordings.contains(where: \.finishedPlan) }
    var body: some View {
        HStack(spacing: 13) {
            Group {
                if complete { Image(systemName: "checkmark") }
                else { Text(number.formatted()).monospacedDigit() }
            }.font(.body.weight(.medium))
                .frame(width: 44, height: 44).background(complete ? RowivoStyle.lime : RowivoStyle.background, in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(workout.displayName).font(.subheadline.weight(.semibold))
                Text(String(format: String(localized: "Planned: %@"), durationText(workout.totalSeconds)))
                    .font(.caption).foregroundStyle(RowivoStyle.muted)
                if let latest = recordings.first {
                    Text(String(format: String(localized: "Last recorded: %@"), durationText(latest.durationSeconds)))
                        .font(.caption.weight(.medium)).foregroundStyle(RowivoStyle.teal)
                    if recordings.count > 1 {
                        Text(String(format: String(localized: "%lld recordings"), Int64(recordings.count)))
                            .font(.caption).foregroundStyle(RowivoStyle.muted)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(RowivoStyle.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        // Include the Spacer and vertical padding in the NavigationLink's hit area.
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct WorkoutRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? RowivoStyle.pale : .clear,
                        in: RoundedRectangle(cornerRadius: 12))
    }
}

struct WorkoutDetailView: View {
    @Environment(RowivoStore.self) private var store
    var workout: Workout
    @State private var logging = false
    @State private var editor: WorkoutEditorRequest?
    @State private var removing = false
    @State private var editingCompletion: WorkoutCompletion?
    private var recordings: [WorkoutCompletion] { store.recordings(for: workout.id) }
    @Environment(\.dismiss) private var dismiss
    private var currentWorkout: Workout { store.state.plan?.workouts.first { $0.id == workout.id } ?? workout }
    private var isNext: Bool { store.nextWorkout?.id == workout.id }
    private var hasMixedIntensities: Bool {
        let active = currentWorkout.segments.filter { $0.kind != .rest }
        return active.contains { $0.intensity == .easy } && active.contains { $0.intensity == .steady }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 13) {
                    Text(currentWorkout.displayName).font(.system(size: 35, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("workout.title")

                }
                if !recordings.isEmpty {
                    Text("Recorded sessions").font(.title3.bold())
                    ForEach(recordings) { log in
                        RecordedWorkoutCard(log: log, context: "workout", showName: false) { editingCompletion = log }
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 19) {
                        Text("Planned workout").font(.title3.bold())
                        HStack(alignment: .top, spacing: 12) {
                            Metric(value: durationText(currentWorkout.totalSeconds), label: "Planned duration")
                            Metric(value: currentWorkout.segments.contains { $0.intensity == .steady } ? localized("Steady") : localized("Easy"), label: "Target intensity")
                        }
                        if recordings.isEmpty {
                            Text("Not recorded yet. Set the workout date when you log your session.")
                                .font(.caption).foregroundStyle(RowivoStyle.muted)
                        } else {
                            Text("These are the original targets. Your recorded results are shown above.")
                                .font(.caption).foregroundStyle(RowivoStyle.muted)
                        }
                        Divider()
                        Text("Workout steps").font(.headline)
                        SegmentBar(workout: currentWorkout)
                        ForEach(Array(currentWorkout.segments.enumerated()), id: \.element.id) { index, segment in
                            HStack(spacing: 14) {
                                Text(String(index + 1)).font(.caption.weight(.medium)).monospacedDigit().frame(width: 25).foregroundStyle(RowivoStyle.muted)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(localized(segment.kind.rawValue)).font(.subheadline.weight(.semibold))
                                    if hasMixedIntensities && segment.kind != .rest {
                                        Text(localized(segment.intensity.rawValue)).font(.caption).foregroundStyle(RowivoStyle.muted)
                                    }
                                }
                                Spacer()
                                Text(clockText(segment.seconds)).font(.subheadline.monospacedDigit())
                            }
                        }
                        if currentWorkout.segments.contains(where: { $0.kind == .rest }) {
                            Text("During rests, pause or move gently.").font(.caption).foregroundStyle(RowivoStyle.muted)
                        }
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Stroke sequence", systemImage: "figure.rower").font(.headline)
                        Text("Push with your legs, open your body, then draw your arms in. Return arms first, then body, then legs.").font(.subheadline).foregroundStyle(RowivoStyle.muted).lineSpacing(3)
                        Link(destination: URL(string: "https://www.concept2.com/training/rowing-technique")!) {
                            Label("Concept2 technique guide", systemImage: "arrow.up.right").font(.caption.weight(.semibold))
                        }
                    }
                }
                if isNext && store.canTrain && store.state.clock == nil {
                    PM5ConnectionCard()
                }
            }.padding(22).padding(.bottom, 20)
        }.rowivoScreen().navigationTitle("Workout").navigationBarTitleDisplayMode(.inline)
            .rowivoBottomBar {
                if isNext {
                    VStack(spacing: 10) {
                        if store.state.clock?.workoutID == workout.id {
                            Button("Resume session") { store.showingWorkout = true }.buttonStyle(PrimaryButton())
                        } else {
                            Button("Start rowing") { store.start(currentWorkout) }.buttonStyle(PrimaryButton())
                                .disabled(!store.canTrain).opacity(store.canTrain ? 1 : 0.45).accessibilityIdentifier("workout.start")
                        }
                        if store.state.clock == nil {
                            Button("Log a completed workout") { logging = true }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                                .buttonStyle(.plain).accessibilityIdentifier("workout.manual")
                        }
                        if store.needsCheckIn {
                            Text("Check in before your next session.").font(.caption).foregroundStyle(RowivoStyle.muted)
                        } else if !store.canTrain, let date = PlanEngine.availableDate(completions: store.state.completions) {
                            Text(String(format: String(localized: "Your next session is available %@."), date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))))
                                .font(.caption).foregroundStyle(RowivoStyle.muted)
                        }
                    }.padding(.horizontal, 22).padding(.vertical, 13)
                } else if store.state.completions.contains(where: { $0.workoutID == workout.id && $0.finishedPlan }) {
                    Label("Session recorded", systemImage: "checkmark.circle.fill")
                        .font(.headline).foregroundStyle(RowivoStyle.teal).padding(20).frame(maxWidth: .infinity)
                        .accessibilityIdentifier("workout.saved")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let log = recordings.first, recordings.count == 1 {
                        Button("Edit session", systemImage: "pencil") { editingCompletion = log }
                            .disabled(store.state.clock != nil).accessibilityIdentifier("workout.edit-recording")
                    } else if recordings.count > 1 {
                        Menu("Edit session", systemImage: "pencil") {
                            ForEach(recordings) { log in
                                Button(log.date.formatted(date: .abbreviated, time: .shortened) + " · " + durationText(log.durationSeconds)) { editingCompletion = log }
                            }
                        }.disabled(store.state.clock != nil).accessibilityIdentifier("workout.edit-recording")
                    } else {
                        Button("Edit", systemImage: "pencil") { edit(copy: false) }
                            .disabled(store.state.clock != nil).accessibilityIdentifier("workout.edit")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Duplicate workout", systemImage: "doc.on.doc") { edit(copy: true) }
                        if !store.hasRecordings(for: workout.id) {
                            Button("Delete workout", role: .destructive) { removing = true }
                        }
                    } label: { Image(systemName: "ellipsis") }
                    .disabled(store.state.clock != nil).accessibilityLabel("Workout options").accessibilityIdentifier("workout.options")
                }
            }
            .sheet(item: $editingCompletion) { RecordedWorkoutEditorView(completion: $0) }
            .sheet(isPresented: $logging) { WorkoutFeedbackView(workout: currentWorkout, seconds: currentWorkout.totalSeconds, manual: true) }
            .sheet(item: $editor) { WorkoutEditorView(request: $0) }
            .confirmationDialog("Delete this workout?", isPresented: $removing, titleVisibility: .visible) {
                Button("Delete workout", role: .destructive) { if store.deleteWorkout(workout.id) { dismiss() } }
            }

    }
    private func edit(copy: Bool) {
        guard let plan = store.state.plan else { return }
        var draft = copy ? ManualPlan.duplicate(currentWorkout) : currentWorkout
        if copy { draft.customName = String(String(format: String(localized: "Copy of %@"), currentWorkout.displayName).prefix(80)) }
        editor = .init(workout: draft, originalID: copy ? nil : currentWorkout.id,
                       blockID: plan.block(for: currentWorkout.id)?.id, baseRevision: plan.revision)
    }

}
