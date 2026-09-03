import SwiftUI

struct SettingsView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pm5 = false
    @State private var storage = false
    @State private var deleting = false
    @State private var deletionFailure: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Your rowing machine") { Button("Concept2 PM5") { pm5 = true } }
                Section("Your data") {
                    Button { storage = true } label: { Label("Files & cloud copies", systemImage: "externaldrive.badge.icloud") }
                        .accessibilityIdentifier("storage.open")
                    Text("Saved locally by default. Export a copy to your own storage whenever you choose.").font(.footnote).foregroundStyle(RowivoStyle.muted)
                }
                if let profile = store.state.profile {
                    Section("Your starting point") {
                        LabeledContent("Name", value: profile.name)
                        LabeledContent("Goal", value: localized(profile.goal.rawValue))
                        LabeledContent("Rowing experience", value: localized(profile.experience.rawValue))
                        LabeledContent("Default workout duration", value: minuteText(profile.sessionMinutes))
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
                    Text("Concept2 PM5 connects via Bluetooth. Apple Watch and HealthKit are planned for later versions.").font(.footnote).foregroundStyle(RowivoStyle.muted)
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
                }
            }.tint(RowivoStyle.teal).scrollContentBackground(.hidden).rowivoScreen()
                .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $pm5) { PM5DeviceView() }
                .sheet(isPresented: $storage) { StorageView() }
                .alert("Delete all local data?", isPresented: $deleting) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete everything", role: .destructive) {
                        Task {
                            if await store.deleteAllData() { dismiss() }
                            else { deletionFailure = store.errorMessage; store.errorMessage = nil }
                        }
                    }.accessibilityIdentifier("settings.confirm-delete")
                } message: {
                    Text("Your profile, plan, history, notes, PM5 recordings, active session, saved credentials and local recovery copies will be deleted. Cloud connections will be removed. Files you already exported stay in your storage. This cannot be undone.")
                }
                .interactiveDismissDisabled(store.isDeletingData)

        }
    }
}
