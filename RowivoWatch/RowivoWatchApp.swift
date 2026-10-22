import SwiftUI

@main struct RowivoWatchApp: App {
    @State private var model = WatchCompanionModel()
    var body: some Scene {
        WindowGroup { WatchWorkoutView().environment(model).tint(WatchStyle.lime) }
    }
}
