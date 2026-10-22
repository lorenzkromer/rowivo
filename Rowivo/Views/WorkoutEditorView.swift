import SwiftUI
import RowivoCore

struct WorkoutEditorRequest: Identifiable {
    let id = UUID()
    var workout: Workout
    var originalID: UUID?
    var blockID: UUID?
    var baseRevision: Int

    static func new(plan: TrainingPlan, minutes: Int, blockID: UUID?) -> Self {
        let workout = Workout(kind: .endurance, segments: [
            .init(kind: .warmup, seconds: 180),
            .init(kind: .work, seconds: max(60, min(60, minutes) * 60 - 360)),
            .init(kind: .cooldown, seconds: 180)
        ])
        return Self(workout: workout, blockID: blockID, baseRevision: plan.revision)
    }
}

struct WorkoutEditorView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: WorkoutEditorRequest
    @State private var workout: Workout
    @State private var blockID: UUID?
    @State private var step: WorkoutSegment?
    @State private var addingIntervals = false
    @State private var reordering = false
    @State private var stepsToDelete: Set<UUID> = []
    @State private var confirmingStepDeletion = false
    @State private var failure: String?

    init(request: WorkoutEditorRequest) {
        self.request = request
        _workout = State(initialValue: request.workout)
        _blockID = State(initialValue: request.blockID)
    }

    private var validation: String? {
        do { try ManualPlan.validateWorkout(workout); return nil }
        catch { return store.message(for: error) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Name (optional)", text: Binding(get: { workout.customName ?? "" }, set: { workout.customName = $0 }))
                        .accessibilityIdentifier("editor.name")
                    Picker("Focus", selection: $workout.kind) {
                        ForEach(WorkoutKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    if let blocks = store.state.plan?.blocks, !blocks.isEmpty {
                        Picker("Training block", selection: $blockID) {
                            ForEach(blocks) { Text(blockText($0.week)).tag(Optional($0.id)) }
                        }.accessibilityIdentifier("editor.block")
                    }
                    LabeledContent("Total time", value: clockText(workout.totalSeconds))
                        .accessibilityIdentifier("editor.total")
                }
                Section {
                    ForEach(Array(workout.segments.enumerated()), id: \.element.id) { index, segment in
                        Button { step = segment } label: {
                            HStack(spacing: 12) {
                                Text((index + 1).formatted()).foregroundStyle(RowivoStyle.muted).frame(width: 22)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(localized(segment.kind.rawValue)).foregroundStyle(RowivoStyle.ink)
                                    if segment.kind != .rest {
                                        Text(localized(segment.intensity.rawValue)).font(.caption).foregroundStyle(RowivoStyle.muted)
                                    }
                                }
                                Spacer()
                                Text(clockText(segment.seconds)).monospacedDigit().foregroundStyle(RowivoStyle.ink)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(RowivoStyle.muted)
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("editor.step.\(index)")
                    }
                    .onDelete { offsets in
                        stepsToDelete = Set(offsets.map { workout.segments[$0].id })
                        confirmingStepDeletion = true
                    }
                    .onMove { workout.segments.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    HStack {
                        Text("Steps")
                        Spacer()
                        Button(reordering ? "Done" : "Reorder") { reordering.toggle() }
                            .accessibilityIdentifier("editor.reorder")
                    }
                } footer: { Text("Tap a step to change its duration or effort. Reorder also lets you remove steps.") }
                Section {
                    Button("Add step", systemImage: "plus") { insert([.init(kind: .work, seconds: 300)]) }
                        .disabled(workout.segments.count >= 100).accessibilityIdentifier("editor.add-step")
                    Button("Add intervals", systemImage: "repeat") { addingIntervals = true }
                        .disabled(workout.segments.count > 97).accessibilityIdentifier("editor.intervals")
                }
                if let message = validation ?? failure {
                    Section { Text(message).foregroundStyle(RowivoStyle.clay).accessibilityIdentifier("editor.error") }
                }
            }
            .environment(\.editMode, .constant(reordering ? .active : .inactive))
            .scrollContentBackground(.hidden).rowivoScreen()
            .navigationTitle(localized(request.originalID == nil ? "New workout" : "Edit workout"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.saveWorkout(workout, replacing: request.originalID, in: blockID, baseRevision: request.baseRevision) { dismiss() }
                        else { failure = store.errorMessage; store.errorMessage = nil }
                    }.disabled(validation != nil || store.state.clock != nil).accessibilityIdentifier("editor.save")
                }
            }
            .sheet(item: $step) { segment in
                StepEditorView(segment: segment) { edited in
                    if let index = workout.segments.firstIndex(where: { $0.id == edited.id }) { workout.segments[index] = edited }
                }
            }
            .sheet(isPresented: $addingIntervals) { IntervalEditorView { insert($0) } }
            .confirmationDialog("Delete selected steps?", isPresented: $confirmingStepDeletion, titleVisibility: .visible) {
                Button("Delete steps", role: .destructive) {
                    workout.segments.removeAll { stepsToDelete.contains($0.id) }
                    stepsToDelete = []
                }
                Button("Cancel", role: .cancel) { stepsToDelete = [] }
            }
        }.interactiveDismissDisabled()
    }

    private func insert(_ segments: [WorkoutSegment]) {
        let index = workout.segments.last?.kind == .cooldown ? workout.segments.count - 1 : workout.segments.count
        var candidate = workout
        candidate.segments.insert(contentsOf: segments, at: index)
        do { try ManualPlan.validateWorkout(candidate); workout = candidate; failure = nil }
        catch { failure = store.message(for: error) }
    }
}

private struct StepEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let original: WorkoutSegment
    let save: (WorkoutSegment) -> Void
    @State private var kind: SegmentKind
    @State private var intensity: Intensity
    @State private var minutesText: String
    @State private var secondsText: String
    init(segment: WorkoutSegment, save: @escaping (WorkoutSegment) -> Void) {
        original = segment; self.save = save
        _kind = State(initialValue: segment.kind); _intensity = State(initialValue: segment.intensity)
        _minutesText = State(initialValue: String(segment.seconds / 60)); _secondsText = State(initialValue: String(segment.seconds % 60))
    }
    private var duration: Int? {
        guard let minutes = Int(minutesText), let seconds = Int(secondsText),
              (0...60).contains(minutes), (0...59).contains(seconds),
              (1...3600).contains(minutes * 60 + seconds) else { return nil }
        return minutes * 60 + seconds
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Step", selection: $kind) {
                        ForEach(SegmentKind.allCases, id: \.self) { Text(localized($0.rawValue)).tag($0) }
                    }.accessibilityIdentifier("step.kind")
                    if kind != .rest {
                        Picker("Effort", selection: $intensity) {
                            ForEach(Intensity.allCases, id: \.self) { Text(localized($0.rawValue)).tag($0) }
                        }
                    }
                }
                Section("Duration") {
                    LabeledContent("Minutes") { TextField("0", text: $minutesText).keyboardType(.numberPad).multilineTextAlignment(.trailing).accessibilityIdentifier("step.minutes") }
                    LabeledContent("Seconds") { TextField("0", text: $secondsText).keyboardType(.numberPad).multilineTextAlignment(.trailing).accessibilityIdentifier("step.seconds") }
                    if duration == nil { Text("Each step must last between 1 second and 60 minutes.").foregroundStyle(RowivoStyle.clay) }
                }
            }.scrollContentBackground(.hidden).rowivoScreen().navigationTitle("Edit step").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            guard let duration else { return }
                            var segment = original
                            segment.kind = kind; segment.intensity = kind == .rest ? .easy : intensity
                            segment.seconds = duration
                            save(segment); dismiss()
                        }.disabled(duration == nil).accessibilityIdentifier("step.save")
                    }
                }
        }.interactiveDismissDisabled()
    }
}

private struct IntervalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let insert: ([WorkoutSegment]) -> Void
    @State private var repetitions = 4
    @State private var rowingText = "2"
    @State private var restText = "1"
    @State private var intensity = Intensity.steady
    private var valid: Bool { (1...60).contains(Int(rowingText) ?? 0) && (1...60).contains(Int(restText) ?? 0) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $repetitions, in: 2...20) { LabeledContent("Repetitions", value: repetitions.formatted()) }
                        .accessibilityIdentifier("intervals.repetitions")
                    LabeledContent("Rowing minutes") { TextField("2", text: $rowingText).keyboardType(.numberPad).multilineTextAlignment(.trailing).accessibilityIdentifier("intervals.row") }
                    LabeledContent("Rest minutes") { TextField("1", text: $restText).keyboardType(.numberPad).multilineTextAlignment(.trailing).accessibilityIdentifier("intervals.rest") }
                    Picker("Effort", selection: $intensity) {
                        ForEach(Intensity.allCases, id: \.self) { Text(localized($0.rawValue)).tag($0) }
                    }
                } footer: { Text("Intervals are inserted before cooling down. No rest is added after the last repetition.") }
            }.scrollContentBackground(.hidden).rowivoScreen().navigationTitle("Add intervals").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Insert") {
                            guard valid, let rowingMinutes = Int(rowingText), let restMinutes = Int(restText) else { return }
                            guard let segments = try? ManualPlan.intervals(repetitions: repetitions, rowingSeconds: rowingMinutes * 60, restSeconds: restMinutes * 60, intensity: intensity) else { return }
                            insert(segments); dismiss()
                        }.disabled(!valid).accessibilityIdentifier("intervals.insert")
                    }
                }
        }.interactiveDismissDisabled()
    }
}

struct PlanOrderView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var workoutsToDelete: [UUID] = []
    @State private var confirmingDeletion = false
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Drag workouts into order. Recorded workouts are kept and cannot be deleted.").font(.subheadline) }
                ForEach(store.state.plan?.blocks ?? []) { block in
                    Section(blockText(block.week)) {
                        ForEach(block.workouts) { workout in
                            Text(workout.displayName).deleteDisabled(store.hasRecordings(for: workout.id))
                        }
                        .onMove { store.reorderWorkouts(in: block.id, from: $0, to: $1) }
                        .onDelete { offsets in
                            workoutsToDelete = offsets.map { block.workouts[$0].id }
                            confirmingDeletion = true
                        }
                    }
                }
            }.rowivoScrollEdges().environment(\.editMode, .constant(.active))
                .disabled(store.state.clock != nil)
                .navigationTitle("Organize plan").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Delete selected workouts?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
                    Button("Delete workouts", role: .destructive) {
                        for id in workoutsToDelete { store.deleteWorkout(id) }
                        workoutsToDelete = []
                    }
                    Button("Cancel", role: .cancel) { workoutsToDelete = [] }
                }
        }
    }
}
