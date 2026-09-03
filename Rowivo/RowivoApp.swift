import SwiftUI
import SwiftData

@main struct RowivoApp: App {
    private let store: RowivoStore?
    init() {
        do {
            let isTesting = ProcessInfo.processInfo.arguments.contains("--uitesting") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            if !isTesting {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let configuration = ModelConfiguration(isStoredInMemoryOnly: isTesting, cloudKitDatabase: .none)
            let container = try ModelContainer(for: StoredState.self, configurations: configuration)
            store = try RowivoStore(container: container)
            #if DEBUG
            if isTesting && ProcessInfo.processInfo.arguments.contains("--seed-profile") {
                store?.createProfile(.init(name: "Alex"), useTemplate: true)
            }
            #endif
        } catch { store = nil }
    }
    var body: some Scene {
        WindowGroup {
            if let store {
                RootView().environment(store).tint(RowivoStyle.ink).preferredColorScheme(.light)
            } else {
                ContentUnavailableView("Could not open your training data", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text("Your saved data has been kept. Close and reopen Rowivo to try again."))
            }
        }
    }
}

enum AppTab: Hashable { case today, plan, progress }

struct RootView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = AppTab.today
    var body: some View {
        @Bindable var store = store
        Group {
            if store.state.profile == nil { OnboardingView() }
            else {
                TabView(selection: $tab) {
                    Tab("Today", systemImage: "sun.max", value: .today) {
                        DashboardView { tab = .plan }
                    }
                    Tab("Plan", systemImage: "square.stack.3d.up", value: .plan) { PlanView() }
                    Tab("Progress", systemImage: "chart.xyaxis.line", value: .progress) { ProgressViewScreen() }
                }
            }
        }
        .onChange(of: store.state.profile) { previous, current in
            if previous == nil, current != nil { tab = .plan }
            if current == nil { tab = .today }
        }
        .disabled(store.isDeletingData)
        .overlay {
            if store.isDeletingData {
                ProgressView("Deleting local data…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .alert("Something needs your attention", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .fullScreenCover(isPresented: $store.showingWorkout) {
            if let workout = store.activeWorkout { ActiveWorkoutView(workout: workout) }
        }
        .task {
            if store.state.clock != nil { store.showingWorkout = true }
            await store.exportIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.flushPM5() }
            // Permission alerts make the scene inactive. Keep the user's search intent
            // through that alert; stop scanning only when the app really backgrounds.
            if phase == .background { store.pm5.stopSearch() }
            if phase == .active { Task { await store.exportIfNeeded() } }
        }
    }
}
