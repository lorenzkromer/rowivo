import SwiftUI

struct WatchConnectionView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "applewatch").font(.system(size: 48)).foregroundStyle(RowivoStyle.teal)
                    Text("Rowivo on your wrist").font(.largeTitle.bold())
                    Text("See your next workout, control the timer and save your feedback from Apple Watch.")
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(status, systemImage: store.watchConnection?.transport.isReachable == true ? "checkmark.circle.fill" : "applewatch.radiowaves.left.and.right")
                                .font(.headline).accessibilityIdentifier("watch.connection-status")
                            Text("Install Rowivo using the Watch app on your iPhone, then open Rowivo on both devices.").font(.subheadline)
                            Button("Sync with Apple Watch") { store.watchConnection?.publish() }
                                .disabled(store.watchConnection?.transport.isInstalled != true)
                                .accessibilityIdentifier("watch.sync")
                        }
                    }
                    Text("Your iPhone remains the recorder and connects to your rower. Keep it nearby while rowing.").font(.subheadline)
                    Text("Device measurements are displayed when available. Watch heart-rate recording and Apple Health are not included yet.")
                        .font(.footnote).foregroundStyle(RowivoStyle.muted)
                    Text("If the connection drops, controls wait until the iPhone is reachable again. Old commands are never queued for later.")
                        .font(.footnote).foregroundStyle(RowivoStyle.muted)
                }.padding(22)
            }.rowivoScreen().navigationTitle("Apple Watch").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private var status: String {
        guard let transport = store.watchConnection?.transport else { return String(localized: "Open Rowivo on a paired iPhone") }
        if transport.activationFailed { return String(localized: "Could not connect. Reopen Rowivo on both devices.") }
        if !transport.isActivated { return String(localized: "Connecting to Apple Watch…") }
        if !transport.isPaired { return String(localized: "No Apple Watch paired") }
        if !transport.isInstalled { return String(localized: "Install Rowivo on Apple Watch") }
        return String(localized: transport.isReachable ? "Apple Watch connected" : "Open Rowivo on Apple Watch")
    }
}
