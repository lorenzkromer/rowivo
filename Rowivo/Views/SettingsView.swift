import SwiftUI
import RowivoCore

struct SettingsView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pm5 = false
    @State private var storage = false
    @State private var watch = false
    @State private var editingProfile = false
    @State private var deleting = false
    @State private var deletionFailure: String?
    private func preference<T>(_ path: WritableKeyPath<WorkoutPreferences, T>) -> Binding<T> {
        Binding(get: { store.workoutPreferences[keyPath: path] }, set: { value in
            var preferences = store.workoutPreferences; preferences[keyPath: path] = value
            store.setWorkoutPreferences(preferences)
        })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Your rowing machine") { Button("Connect a rowing machine") { pm5 = true } }
                Section {
                    Toggle("Automatic pause", isOn: preference(\.automaticPause))
                        .accessibilityIdentifier("settings.auto-pause")
                    if store.workoutPreferences.automaticPause {
                        Stepper(value: preference(\.powerThreshold), in: 1...50) {
                            LabeledContent("Power threshold", value: "\(store.workoutPreferences.powerThreshold) W")
                        }.accessibilityIdentifier("settings.power-threshold")
                    }
                    Toggle("Phase sounds", isOn: preference(\.phaseSounds))
                } header: { Text("During training") } footer: {
                    Text("Pause after 6 seconds below the threshold; resume after 2 seconds at least 4 W above it. Planned rests continue normally. Manual pauses stay paused. Requires live power readings.")
                }
                Section("Apple Watch") { Button("Apple Watch companion") { watch = true }.accessibilityIdentifier("watch.open") }
                Section("Your data") {
                    Button { storage = true } label: { Label("Files & cloud copies", systemImage: "externaldrive.badge.icloud") }
                        .accessibilityIdentifier("storage.open")
                    Text("Saved locally by default. Export a copy to your own storage whenever you choose.").font(.footnote).foregroundStyle(RowivoStyle.muted)
                }
                if let profile = store.state.profile {
                    Section("Your profile") {
                        LabeledContent("Name", value: profile.name)
                        LabeledContent("Goal", value: localized(profile.goal.rawValue))
                        LabeledContent("Rowing experience", value: localized(profile.experience.rawValue))
                        LabeledContent("Default workout duration", value: minuteText(profile.sessionMinutes))
                        Button("Edit profile") { editingProfile = true }
                            .disabled(store.isTransferringFiles).accessibilityIdentifier("profile.edit")
                    }
                }
                Section("Language") {
                    LabeledContent("App language", value: Locale.current.language.languageCode?.identifier == "de" ? "Deutsch" : "English")
                    Button("Open iPhone settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    Text("Rowivo supports English and German. Change the app language in iPhone settings.").font(.footnote).foregroundStyle(RowivoStyle.muted)
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Text("Concept2 PM5 and compatible FTMS rowers connect via Bluetooth. Apple Watch controls your session through the paired iPhone.").font(.footnote).foregroundStyle(RowivoStyle.muted)
                } header: { Text("Rowivo") }
                Section {
                    Button("Delete profile and data", role: .destructive) { deletionFailure = nil; deleting = true }
                        .disabled(store.isTransferringFiles).accessibilityIdentifier("settings.delete")
                    if let deletionFailure {
                        Text(deletionFailure).font(.footnote).foregroundStyle(RowivoStyle.clay)
                            .accessibilityIdentifier("settings.delete-error")
                    }
                    if store.isTransferringFiles {
                        Label("Working with your files…", systemImage: "hourglass").font(.footnote)
                    }
                } footer: {
                    Text("Remove your profile and all Rowivo training data from this iPhone, then start again with onboarding.")
                    Text("Workouts already saved to Apple Health remain in Health.")
                }
            }.tint(RowivoStyle.teal).scrollContentBackground(.hidden).rowivoScreen()
                .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $pm5) { RowerDeviceView() }
                .sheet(isPresented: $storage) { StorageView() }
                .sheet(isPresented: $watch) { WatchConnectionView() }
                .sheet(isPresented: $editingProfile) {
                    if let profile = store.state.profile { ProfileEditorView(profile: profile) }
                }
                .alert("Delete all local data?", isPresented: $deleting) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete everything", role: .destructive) {
                        Task {
                            if await store.deleteAllData() { dismiss() }
                            else { deletionFailure = store.errorMessage; store.errorMessage = nil }
                        }
                    }.accessibilityIdentifier("settings.confirm-delete")
                } message: {
                    Text("Your profile, plan, history, notes, device recordings, active session, saved credentials and local recovery copies will be deleted. Cloud connections will be removed. Files you already exported stay in your storage. This cannot be undone.")
                }
                .interactiveDismissDisabled(store.isDeletingData)

        }
    }
}

private struct ProfileEditorView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var original: TrainingProfile
    @State private var draft: TrainingProfile
    @State private var error: String?

    init(profile: TrainingProfile) {
        _original = State(initialValue: profile)
        _draft = State(initialValue: profile)
    }
    private var validName: Bool {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 200
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Your profile") {
                    TextField("Your name", text: $draft.name).textContentType(.givenName).submitLabel(.done)
                        .accessibilityIdentifier("profile.editor.name")
                    Picker("Goal", selection: $draft.goal) {
                        ForEach(TrainingGoal.allCases, id: \.self) { Text(localized($0.rawValue)).tag($0) }
                    }.accessibilityIdentifier("profile.editor.goal")
                    Picker("Rowing experience", selection: $draft.experience) {
                        ForEach(Experience.allCases, id: \.self) { Text(localized($0.rawValue)).tag($0) }
                    }.accessibilityIdentifier("profile.editor.experience")
                }
                Section {
                    Picker("Default workout duration", selection: $draft.sessionMinutes) {
                        // Preserve valid values from older backups, including non-preset durations.
                        ForEach(Array(Set([15, 20, 25, 30, 40, 50, 60, original.sessionMinutes])).sorted(), id: \.self) {
                            Text(minuteText($0)).tag($0)
                        }
                    }.accessibilityIdentifier("profile.editor.duration")
                } footer: {
                    Text("The default duration applies to new workouts. Your existing plan and recorded sessions stay unchanged.")
                }
                if !validName {
                    Text("Enter a name between 1 and 200 characters.").font(.footnote).foregroundStyle(RowivoStyle.clay)
                }
                if let error { Text(error).foregroundStyle(RowivoStyle.clay).accessibilityIdentifier("profile.editor.error") }
            }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).rowivoScreen()
                .navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.accessibilityIdentifier("profile.editor.cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if store.updateProfile(draft, replacing: original) { dismiss() }
                            else { error = store.errorMessage; store.errorMessage = nil }
                        }.disabled(!validName || store.isTransferringFiles || store.isDeletingData)
                            .accessibilityIdentifier("profile.editor.save")
                    }
                }
        }.tint(RowivoStyle.teal)
    }
}
