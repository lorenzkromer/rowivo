import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let rowivoBackup = UTType(exportedAs: "app.rowivo.training-backup", conformingTo: .json)
}

enum StoragePickerMode: Identifiable {
    case folder, backup, export([URL])
    var id: String {
        switch self { case .folder: "folder"; case .backup: "backup"; case .export: "export" }
    }
}

struct StorageView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picker: StoragePickerMode?
    @State private var pickerVisible = false
    @State private var pendingPreview: TrainingArchive?
    @State private var preview: TrainingArchive?
    private var canTransfer: Bool { !store.isTransferringFiles && store.state.clock == nil }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "externaldrive.badge.icloud").font(.system(size: 42, weight: .light)).foregroundStyle(RowivoStyle.teal)
                        Text("Your data. Your choice.").font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Rowivo saves your training on this iPhone. You can also keep a copy in a folder you choose.")
                            .foregroundStyle(RowivoStyle.muted).font(.subheadline).lineSpacing(3)
                    }
                    if store.state.clock != nil {
                        Label("Finish your active session before exporting or restoring training.", systemImage: "pause.circle")
                            .font(.subheadline).foregroundStyle(RowivoStyle.clay)
                    }
                    if store.state.profile != nil {
                        Surface {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Files & cloud copies", systemImage: "folder").font(.headline)
                                if let folder = store.state.cloudExport {
                                    LabeledContent("Selected folder", value: folder.folderName).font(.subheadline)
                                    Toggle("Copy after each saved session", isOn: Binding(get: { store.state.cloudExport?.automaticallyExport == true }, set: { store.setAutomaticExport($0) }))
                                        .tint(RowivoStyle.teal).font(.subheadline).disabled(store.isTransferringFiles).accessibilityIdentifier("storage.auto")
                                    Text("Also updates after plan changes. If a copy fails, Rowivo retries when you next open the app. Previous copies are kept.")
                                        .font(.caption).foregroundStyle(RowivoStyle.muted)
                                    if let date = folder.lastExportAt {
                                        LabeledContent("Last copy handed over", value: date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                    }
                                    if folder.pending {
                                        Label("Changes waiting to be copied", systemImage: "clock.arrow.circlepath").font(.caption).foregroundStyle(RowivoStyle.clay)
                                    }
                                    Button("Save a copy now") { Task { await store.exportToFolder() } }
                                        .buttonStyle(PrimaryButton()).disabled(!canTransfer).accessibilityIdentifier("storage.save")
                                    HStack {
                                        Button("Change folder") { picker = .folder }
                                        Spacer()
                                        Button("Disconnect", role: .destructive) { store.disconnectCloudFolder() }
                                    }.font(.subheadline).disabled(store.isTransferringFiles)
                                } else {
                                    Text("Cloud copies are off. Choose a folder to enable them.").font(.subheadline).foregroundStyle(RowivoStyle.muted)
                                        .accessibilityIdentifier("storage.off")
                                    Button("Choose a folder") { picker = .folder }.buttonStyle(PrimaryButton())
                                        .disabled(store.isTransferringFiles).accessibilityIdentifier("storage.folder")
                                }
                                Text("Use iCloud Drive or a provider enabled in the Files app, such as Google Drive or Microsoft OneDrive. Install its app and sign in first.")
                                    .font(.caption).foregroundStyle(RowivoStyle.muted).lineSpacing(3)
                            }
                        }
                        Surface {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Take your data anywhere").font(.headline)
                                Text("Export CSV files and a training backup once, without remembering a folder. Use this if your provider does not support folder access.")
                                    .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                                Button("Export files…") {
                                    Task {
                                        if let urls = await store.prepareFileExport() { picker = .export(urls) }
                                    }
                                }.font(.subheadline.bold()).disabled(!canTransfer).accessibilityIdentifier("storage.export")
                            }
                        }
                    }
                    if store.isTransferringFiles { HStack { ProgressView(); Text("Working with your files…").font(.subheadline) } }
                    if let message = store.storageMessage {
                        Label(message, systemImage: store.storageFailed ? "exclamationmark.circle" : "checkmark.circle")
                            .font(.subheadline).foregroundStyle(store.storageFailed ? RowivoStyle.clay : RowivoStyle.teal)
                            .accessibilityIdentifier("storage.status")
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Restore your training", systemImage: "arrow.counterclockwise").font(.headline)
                            Text("Choose a Rowivo training backup to preview its date and sessions before restoring. CSV files are for your own analysis.")
                                .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                            Button("Choose a backup…") { picker = .backup }.font(.subheadline.bold()).disabled(!canTransfer)
                                .accessibilityIdentifier("storage.restore")
                            if store.state.restoreRecoveryName != nil {
                                Button("Recover the previous training state") { Task { preview = await store.inspectRecovery() } }
                                    .font(.subheadline).disabled(!canTransfer)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What's in a copy?").font(.headline)
                        Text("Profile, plan, saved workouts, feedback and PM5 measurements, including heart rate when available. Unfinished workouts are excluded.")
                        Text("CSV tables are open and reusable. The additional training.rowivo file preserves your training for restoration, including plan history.")
                        Text("Your chosen provider stores these copies and manages uploads. Rowivo cannot confirm a server upload. This is a backup, not live sync between devices.")
                    }.font(.caption).foregroundStyle(RowivoStyle.muted).lineSpacing(3)
                }.padding(22)
            }.rowivoScreen().navigationTitle("Your data").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(item: $picker, onDismiss: pickerDidClose) { mode in
                    // UIKit may dismiss before its delegate fires. Process the result
                    // in the delegate; only defer the next sheet until this one closes.
                    StorageDocumentPicker(mode: mode) { urls in
                        picker = nil
                        processSelection(mode: mode, urls: urls)
                    }
                    .onAppear { pickerVisible = true }
                    .onDisappear(perform: pickerDidClose)
                }
                .sheet(isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } })) {
                    if let archive = preview {
                        RestoreTrainingView(archive: archive) { preview = nil }
                    }
                }
        }
    }

    private func pickerDidClose() {
        pickerVisible = false
        if let pendingPreview { preview = pendingPreview; self.pendingPreview = nil }
    }

    private func processSelection(mode: StoragePickerMode, urls: [URL]?) {
        Task {
            switch mode {
            case .folder: if let url = urls?.first { await store.chooseCloudFolder(url) }
            case .backup:
                if let url = urls?.first, let archive = await store.inspectBackup(url) {
                    if pickerVisible { pendingPreview = archive } else { preview = archive }
                }
            case .export(let files): await store.finishFileExport(files, saved: urls?.isEmpty == false)
            }
        }
    }
}

private struct RestoreTrainingView: View {
    @Environment(RowivoStore.self) private var store
    var archive: TrainingArchive
    var close: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Selected backup") {
                    LabeledContent("Name", value: archive.profile.name)
                    LabeledContent("Created", value: archive.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Sessions recorded", value: archive.completions.count.formatted())
                }
                Section {
                    Text("Restoring replaces your profile, plan and training history. Rowivo keeps a local recovery copy of your previous training.")
                    Text("Cloud folder access will be turned off. You can choose a folder again afterwards.")
                    Button("Restore this training", role: .destructive) {
                        Task { if await store.restoreTraining(archive) { close() } }
                    }.disabled(store.isTransferringFiles || store.state.clock != nil).accessibilityIdentifier("storage.confirm-restore")
                }
                if store.isTransferringFiles { ProgressView() }
                if store.storageFailed, let message = store.storageMessage { Text(message).foregroundStyle(RowivoStyle.clay) }
            }.rowivoScrollEdges().navigationTitle("Review backup").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: close).disabled(store.isTransferringFiles) } }
        }.interactiveDismissDisabled(store.isTransferringFiles)
    }
}

private struct StorageDocumentPicker: UIViewControllerRepresentable {
    var mode: StoragePickerMode
    var picked: ([URL]?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(picked: picked) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller: UIDocumentPickerViewController
        switch mode {
        case .folder: controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        case .backup: controller = UIDocumentPickerViewController(forOpeningContentTypes: [.rowivoBackup, .json], asCopy: false)
        case .export(let urls): controller = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        }
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        controller.shouldShowFileExtensions = true
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var picked: ([URL]?) -> Void
        init(picked: @escaping ([URL]?) -> Void) { self.picked = picked }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { picked(urls) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { picked(nil) }
    }
}
