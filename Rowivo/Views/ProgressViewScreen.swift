import SwiftUI
import CoreText
import Charts
import RowivoCore

struct ProgressViewScreen: View {
    @Environment(RowivoStore.self) private var store
    @State private var revisions = false
    @State private var editingCompletion: WorkoutCompletion?
    private var totalSeconds: Int { store.state.completions.reduce(0) { $0 + $1.durationSeconds } }
    private var chartDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let dates = store.state.completions.map(\.date)
        let first = calendar.startOfDay(for: dates.min() ?? Date())
        let last = calendar.startOfDay(for: dates.max() ?? Date())
        return first...(calendar.date(byAdding: .day, value: 1, to: last) ?? last)
    }
    private var chartDayStride: Int {
        let range = chartDateRange
        let days = Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 1
        return max(1, Int(ceil(Double(days) / 5)))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Training history").font(.system(size: 33, weight: .bold, design: .rounded)).tracking(-1)
                        Text("Time, effort and notes in one place.").foregroundStyle(RowivoStyle.muted)
                        if store.state.clock != nil {
                            Text("Finish your active session before editing recorded workouts.").font(.footnote).foregroundStyle(RowivoStyle.muted)
                        }
                    }
                    Surface {
                        HStack {
                            Metric(value: store.state.completions.count.formatted(), label: "Sessions recorded")
                            Metric(value: durationText(totalSeconds), label: "Total training time")
                        }
                    }
                    if store.state.completions.isEmpty {
                        VStack(spacing: 17) {
                            Image(systemName: "chart.xyaxis.line").font(.system(size: 45, weight: .light)).foregroundStyle(RowivoStyle.teal)
                            Text("Nothing recorded yet").font(.title3.bold())
                            Text("Saved workouts will appear here.")
                                .font(.subheadline).foregroundStyle(RowivoStyle.muted).multilineTextAlignment(.center)
                        }.padding(32).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 26))
                    } else {
                        Surface {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("Training time").font(.headline)
                                Chart {
                                    ForEach(store.state.completions) { log in
                                        BarMark(x: .value(localized("Date"), log.date, unit: .day), y: .value(localized("Minutes"), Double(log.durationSeconds) / 60))
                                            .foregroundStyle(RowivoStyle.teal).cornerRadius(5)
                                    }
                                }
                                .chartXScale(domain: chartDateRange)
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day, count: chartDayStride)) { _ in
                                        AxisGridLine(); AxisTick()
                                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                    }
                                }
                                .chartYAxisLabel(localized("Minutes")).frame(height: 160)
                            }
                        }
                        Text("Logged workouts").font(.title3.bold())
                        ForEach(store.state.completions.sorted { $0.date > $1.date }) { log in
                            RecordedWorkoutCard(log: log, context: "history") { editingCompletion = log }
                        }
                    }
                    Button("View plan changes") { revisions = true }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                }.padding(22)
            }.rowivoScreen().navigationTitle("Progress").navigationBarTitleDisplayMode(.inline)
                .sheet(item: $editingCompletion) { RecordedWorkoutEditorView(completion: $0) }
                .sheet(isPresented: $revisions) {
                    NavigationStack {
                        List(store.state.revisions.reversed()) { revision in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: String(localized: "Plan version %lld"), Int64(revision.plan.revision))).font(.headline)
                                Text(localized(revision.reason))
                                Text(revision.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 8)
                        }.rowivoScrollEdges().navigationTitle("Plan changes")
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { revisions = false } } }
                    }
                }
        }
    }
}

/// The same saved values and edit action appear in Today, Plan and Progress.
struct RecordedWorkoutCard: View {
    @Environment(RowivoStore.self) private var store
    let log: WorkoutCompletion
    let context: String
    var showName = true
    var edit: () -> Void
    @State private var pdf: WorkoutPDFFile?
    @State private var pdfError: String?
    private var plannedWorkout: Workout? { store.state.plan?.workouts.first { $0.id == log.workoutID } }

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if showName || log.displayName != plannedWorkout?.displayName { Text(log.displayName).font(.headline) }
                    Text(log.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                        .accessibilityIdentifier("\(context).date.\(log.id.uuidString)")
                }
                HStack(alignment: .top, spacing: 12) {
                    Metric(value: durationText(log.durationSeconds), label: "Actual duration")
                        .accessibilityIdentifier("\(context).actual.\(log.id.uuidString)")
                    if let plannedWorkout {
                        Metric(value: durationText(plannedWorkout.totalSeconds), label: "Planned duration")
                            .accessibilityIdentifier("\(context).planned.\(log.id.uuidString)")
                    }
                }
                Label(String(format: String(localized: "Reported effort: %lld/5"), Int64(log.effort)), systemImage: "waveform.path.ecg")
                    .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                if log.pm5 == nil {
                    Text(localized(log.manuallyRecorded ? "Entered manually" : "Timed with Rowivo"))
                        .font(.caption).foregroundStyle(RowivoStyle.muted)
                }
                if log.editedAt != nil {
                    Label("Edited", systemImage: "pencil").font(.caption).foregroundStyle(RowivoStyle.muted)
                }
                if !log.finishedPlan {
                    Text(localized(store.recordings(for: log.workoutID).contains(where: \.finishedPlan) ? "Partial session" : "Partial session. This workout remains open in the plan."))
                        .font(.caption).foregroundStyle(RowivoStyle.clay)
                }
                if log.discomfort { Label("Discomfort reported", systemImage: "heart.text.clipboard").font(.caption).foregroundStyle(RowivoStyle.clay) }
                if !log.note.isEmpty { Text(log.note).font(.subheadline).foregroundStyle(RowivoStyle.muted) }
                if let recording = log.pm5 {
                    Divider()
                    RowerRecordingSummary(recording: recording)
                    NavigationLink("View device recording") { RowerRecordingDetailView(recording: recording) }
                        .font(.subheadline.weight(.semibold)).accessibilityIdentifier("pm5.\(context)")
                }
                Button(action: edit) {
                    Label("Edit session", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(store.state.clock != nil)
                    .accessibilityIdentifier("\(context).edit-recording.\(log.id.uuidString)")
                Button("Share as PDF", systemImage: "square.and.arrow.up") {
                    do { pdf = WorkoutPDFFile(url: try WorkoutPDF.create(log, planned: plannedWorkout)) }
                    catch { pdfError = error.localizedDescription }
                }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    .accessibilityIdentifier("\(context).share-pdf.\(log.id.uuidString)")
                if let pdfError { Text(pdfError).font(.caption).foregroundStyle(RowivoStyle.clay) }
                if store.state.clock != nil {
                    Text("Finish your active session before editing recorded workouts.").font(.caption).foregroundStyle(RowivoStyle.muted)
                }
            }
        }.sheet(item: $pdf) { WorkoutPDFShare(url: $0.url) }
    }
}

struct RecordedWorkoutEditorView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let completion: WorkoutCompletion
    @State private var edit: RecordedWorkoutEdit
    @State private var minutes: String
    @State private var seconds: String
    @State private var failure: String?
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case name, minutes, seconds, note }
    private var plannedWorkout: Workout? { store.state.plan?.workouts.first { $0.id == completion.workoutID } }

    init(completion: WorkoutCompletion) {
        self.completion = completion
        _edit = State(initialValue: RecordedWorkoutEdit(completion))
        _minutes = State(initialValue: String(completion.durationSeconds / 60))
        _seconds = State(initialValue: String(completion.durationSeconds % 60))
    }

    private var draft: RecordedWorkoutEdit? {
        guard let minutes = Int(minutes), let seconds = Int(seconds),
              (0...240).contains(minutes), (0...59).contains(seconds) else { return nil }
        var result = edit
        result.durationSeconds = minutes * 60 + seconds
        return result
    }
    private var validation: String? {
        guard let draft else { return store.message(for: RecordedWorkoutEditError.invalidDuration) }
        do { try draft.validate(); return nil }
        catch { return store.message(for: error) }
    }
    private var effortLabel: String { localized(["Very easy", "Comfortable", "Moderate", "Hard", "Very hard"][edit.effort - 1]) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Name (optional)", text: $edit.name).focused($focusedField, equals: .name)
                        .submitLabel(.done).accessibilityIdentifier("recording.editor.name")
                    Picker("Focus", selection: $edit.kind) {
                        ForEach(WorkoutKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.accessibilityIdentifier("recording.editor.kind")
                    DatePicker("Workout date", selection: $edit.date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact).accessibilityIdentifier("recording.editor.date")
                }
                Section {
                    LabeledContent("Minutes") {
                        TextField("0", text: $minutes).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .minutes).accessibilityIdentifier("recording.editor.minutes")
                    }
                    LabeledContent("Seconds") {
                        TextField("0", text: $seconds).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .seconds).accessibilityIdentifier("recording.editor.seconds")
                    }
                    if let plannedWorkout {
                        LabeledContent("Planned duration", value: durationText(plannedWorkout.totalSeconds)).foregroundStyle(RowivoStyle.muted)
                        if let draft, draft.durationSeconds < plannedWorkout.totalSeconds,
                           !store.recordings(for: completion.workoutID).contains(where: { $0.id != completion.id && $0.finishedPlan }) {
                            Text("This will be saved as a partial session. The planned workout stays open.")
                                .font(.footnote).foregroundStyle(RowivoStyle.clay)
                        }
                    }
                } header: { Text("Actual duration") }
                  footer: { Text("Your corrections update this entry, your history and your plan progress.") }
                Section("Your feedback") {
                    HStack {
                        Text("Effort")
                        Spacer()
                        Text(effortLabel).foregroundStyle(RowivoStyle.muted)
                    }
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { value in
                            Button { edit.effort = value } label: {
                                Text(value.formatted()).font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                                    .background(edit.effort == value ? RowivoStyle.lime : RowivoStyle.background, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                                .accessibilityLabel(localized(["Very easy", "Comfortable", "Moderate", "Hard", "Very hard"][value - 1]))
                                .accessibilityValue("\(value)/5")
                                .accessibilityAddTraits(edit.effort == value ? .isSelected : [])
                                .accessibilityIdentifier("recording.editor.effort.\(value)")
                        }
                    }
                    Toggle("I felt pain or discomfort", isOn: $edit.discomfort)
                        .accessibilityIdentifier("recording.editor.discomfort")
                }
                Section("Notes") {
                    TextEditor(text: $edit.note).frame(minHeight: 110).focused($focusedField, equals: .note)
                        .accessibilityLabel("Notes").accessibilityIdentifier("recording.editor.note")
                }
                if completion.pm5 != nil {
                    Section {
                        Text("Device measurements remain as recorded. Changes here correct your session details, including its duration.")
                            .font(.footnote)
                    }
                }
                Section {
                    DeleteRecordedWorkoutButton(completion: completion, context: "recording.editor") { dismiss() }
                }
                if let message = validation ?? failure {
                    Section { Text(message).foregroundStyle(RowivoStyle.clay).accessibilityIdentifier("recording.editor.error") }
                }
            }.scrollContentBackground(.hidden).rowivoScreen().scrollDismissesKeyboard(.interactively)
                .navigationTitle("Edit session").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Edit session").font(.headline).lineLimit(2)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.accessibilityIdentifier("recording.editor.cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let draft else { return }
                            if store.updateCompletion(completion, with: draft) { dismiss() }
                            else { failure = store.errorMessage; store.errorMessage = nil }
                        }.disabled(validation != nil || store.state.clock != nil).accessibilityIdentifier("recording.editor.save")
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focusedField = nil }.padding(.vertical, 8).accessibilityIdentifier("recording.editor.keyboard-done")
                    }
                }
                .onSubmit { focusedField = nil }
        }.interactiveDismissDisabled()
    }
}

private struct DeleteRecordedWorkoutButton: View {
    @Environment(RowivoStore.self) private var store
    let completion: WorkoutCompletion
    let context: String
    var onDeleted: () -> Void = {}
    @State private var confirming = false
    @State private var failure: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(role: .destructive) { confirming = true } label: {
                Label("Delete session", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(.red)
                .disabled(store.state.clock != nil || store.isTransferringFiles || store.isDeletingData)
                .accessibilityIdentifier("\(context).delete-recording.\(completion.id.uuidString)")
            if let failure { Text(failure).font(.footnote).foregroundStyle(RowivoStyle.clay) }
        }
        .alert("Delete this saved session?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) { }
            Button("Delete session", role: .destructive) {
                if store.deleteCompletion(completion) { onDeleted() }
                else { failure = store.errorMessage; store.errorMessage = nil }
            }.accessibilityIdentifier("recording.delete.confirm")
        } message: {
            Text(completion.displayName + " · " + completion.date.formatted(date: .abbreviated, time: .shortened)
                 + "\n\n" + localized("This removes this recording and its device data from Rowivo. The planned workout stays available. Existing Apple Health entries and exported copies are kept. This cannot be undone."))
        }
    }
}

private struct WorkoutPDFFile: Identifiable { let id = UUID(); let url: URL }
private struct WorkoutPDFShare: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor enum WorkoutPDF {
    static func create(_ log: WorkoutCompletion, planned: Workout?) throws -> URL {
        let text = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle(); paragraph.paragraphSpacing = 10; paragraph.lineSpacing = 3
        func append(_ value: String, size: CGFloat = 12, bold: Bool = false) {
            text.append(NSAttributedString(string: value + "\n", attributes: [
                .font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
                .foregroundColor: UIColor(red: 0.07, green: 0.20, blue: 0.20, alpha: 1), .paragraphStyle: paragraph]))
        }
        append("rowivo", size: 30, bold: true)
        append(log.displayName, size: 21, bold: true)
        append(log.date.formatted(date: .complete, time: .shortened))
        append(localized("Actual duration") + ": " + durationText(log.durationSeconds), size: 16, bold: true)
        if let planned { append(localized("Planned duration") + ": " + durationText(planned.totalSeconds)) }
        append(String(format: String(localized: "Reported effort: %lld/5"), Int64(log.effort)))
        append(localized(log.manuallyRecorded ? "Entered manually" : "Timed with Rowivo"))
        if !log.finishedPlan { append(localized("Partial session")) }
        if log.discomfort { append(localized("Discomfort reported")) }
        if log.editedAt != nil { append(localized("Edited")) }
        if let device = log.pm5 {
            append(device.deviceName, size: 16, bold: true)
            if let meters = device.measuredDistance { append(localized("Meters") + ": " + meters.formatted(.number.precision(.fractionLength(1)))) }
            if let seconds = device.measuredTime { append(localized("Device rowing time") + ": " + clockText(Int(seconds))) }
            if let pace = device.averagePace { append(localized("Average pace") + ": " + clockText(Int(pace)) + " /500 m") }
            if device.hasGaps { append(localized("The recording contains gaps. Device totals may be incomplete.")) }
            append(localized("Device measurements are separate from the app timer."))
        }
        if !log.note.isEmpty { append(localized("Notes"), size: 16, bold: true); append(log.note) }
        if let planned {
            append(localized("Planned workout"), size: 16, bold: true)
            for step in planned.segments { append(localized(step.kind.rawValue) + " · " + durationText(step.seconds)) }
        }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let data = renderer.pdfData { context in
            var offset = 0; var page = 0
            while offset < text.length {
                context.beginPage(); page += 1
                let cg = context.cgContext
                cg.saveGState(); cg.textMatrix = .identity
                cg.translateBy(x: 0, y: 842); cg.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: CGRect(x: 44, y: 60, width: 507, height: 738), transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
                CTFrameDraw(frame, cg)
                let visible = CTFrameGetVisibleStringRange(frame)
                cg.restoreGState()
                ("Rowivo · " + String(page) as NSString).draw(at: CGPoint(x: 44, y: 804), withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.secondaryLabel])
                guard visible.length > 0 else { break }
                offset += visible.length
            }
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Rowivo-PDF-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        let url = directory.appendingPathComponent("Rowivo-" + formatter.string(from: log.date) + ".pdf")
        try data.write(to: url, options: .atomic)
        return url
    }
}
