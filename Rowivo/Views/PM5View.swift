import SwiftUI
import Charts
import RowivoCore

func paceText(_ seconds: Double?) -> String {
    guard let seconds, seconds.isFinite, seconds > 0 else { return "—" }
    return clockText(Int(seconds.rounded()))
}
func metersText(_ meters: Double?) -> String { meters.map { $0.formatted(.number.precision(.fractionLength(0))) + " m" } ?? "—" }

struct RowerConnectionCard: View {
    @Environment(RowivoStore.self) private var store
    @State private var showingDevice = false
    var body: some View {
        Button { showingDevice = true } label: {
            HStack(spacing: 14) {
                Image(systemName: store.rower.isConnected ? "antenna.radiowaves.left.and.right" : "figure.rower")
                    .font(.title2).foregroundStyle(RowivoStyle.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized(store.rower.state.rawValue)).font(.subheadline.bold())
                    Text(localized(store.rower.isConnected ? "Live metrics from your rower" : "Concept2 PM5 · FTMS"))
                        .font(.caption).foregroundStyle(RowivoStyle.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }.padding(17).background(RowivoStyle.pale, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityIdentifier("pm5.open")
            .sheet(isPresented: $showingDevice) { RowerDeviceView() }
    }
}

struct RowerDeviceView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDisconnect = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image(systemName: "figure.rower").font(.system(size: 52, weight: .light)).foregroundStyle(RowivoStyle.teal)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Concept2 PM5 and FTMS rowers").font(.title2.bold())
                            Text(localized(store.rower.state.rawValue)).font(.subheadline).foregroundStyle(RowivoStyle.muted)
                                .accessibilityIdentifier("pm5.status")
                        }
                    }.padding(.top, 10)
                    if store.rower.isConnected {
                        RowerLivePanel()
                        if let name = store.rower.selectedDevice?.name { Label(name, systemImage: "checkmark.circle.fill").font(.subheadline) }
                        Button("Disconnect rower", role: .destructive) { confirmingDisconnect = true }.accessibilityIdentifier("pm5.disconnect")
                    } else {
                        Surface {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Ready in three steps").font(.headline)
                                Text("1. Enable Bluetooth pairing on your rower. On a PM5, open Connect. Disconnect other training apps if needed.")
                                Text("2. Search below and select your device. FTMS devices are checked for rowing support when connecting.")
                                Text("3. Choose free rowing on your device (Just Row on PM5), start your Rowivo session, then begin rowing.")
                            }.font(.subheadline).lineSpacing(3)
                        }
                        if store.rower.isSimulator {
                            Label("A real iPhone is needed to connect to a rower. Bluetooth is unavailable in the simulator.", systemImage: "iphone")
                                .font(.subheadline).foregroundStyle(RowivoStyle.muted).accessibilityIdentifier("pm5.simulator")
                        }
                        if [.poweredOff, .unauthorized].contains(store.rower.state) {
                            Text("Enable Bluetooth and allow Rowivo to use it in iPhone settings.").font(.subheadline)
                            Button("Open iPhone settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                        if store.rower.state == .failed {
                            Text("Keep your rower awake and nearby, enable pairing again, then retry. Close other apps using the device.")
                                .font(.subheadline).foregroundStyle(RowivoStyle.clay)
                        }
                        if store.rower.isBusy {
                            HStack { ProgressView(); Text(localized(store.rower.state.rawValue)).font(.subheadline) }
                            Button("Cancel search") {
                                if store.rower.state == .scanning { store.rower.stopSearch() } else { store.rower.disconnect() }
                            }
                        } else {
                            Button("Find rowing machines") { store.rower.search() }.buttonStyle(PrimaryButton()).accessibilityIdentifier("pm5.search")
                        }
                        ForEach(store.rower.devices) { device in
                            Button { store.rower.connect(device) } label: {
                                Surface {
                                    HStack {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(device.name).font(.headline)
                                            Text(device.deviceProtocol == .concept2 ? "Concept2 PM5" : "FTMS · rowing support checked on connection")
                                                .font(.caption).foregroundStyle(RowivoStyle.muted)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                    }
                                }
                            }.buttonStyle(.plain).disabled(store.rower.state != .scanning && store.rower.isBusy)
                        }
                        if store.rower.devices.isEmpty && store.rower.state == .idle {
                            Text("Supported devices appear here while Bluetooth pairing is enabled.").font(.caption).foregroundStyle(RowivoStyle.muted)
                        }
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your rower, your session").font(.headline)
                            Text("Bluetooth alone does not guarantee compatibility. Your device must provide PM5 or FTMS rowing data. Available measurements depend on its model and firmware.")
                            Text("Rowivo guides the intervals on your iPhone. Starting or pausing Rowivo does not control the device or its resistance.")
                            Text("Only measurements received during your running Rowivo session are recorded. Gaps are marked. Measurements stay local and are included in optional file exports.")
                        }.font(.caption).foregroundStyle(RowivoStyle.muted).lineSpacing(3)
                    }
                }.padding(22)
            }.rowivoScreen().navigationTitle("Your rowing machine").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Disconnect your rower?", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
                    Button("Disconnect rower", role: .destructive) { store.rower.disconnect() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Live device measurements will stop until you reconnect. Your saved recordings are kept.")
                }
                .onDisappear { store.rower.stopSearch() }
        }
    }
}

struct RowerLivePanel: View {
    @Environment(RowivoStore.self) private var store
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = store.rower.latest
            let fresh = store.rower.isConnected && snapshot.map { timeline.date.timeIntervalSince($0.date) <= 5 } == true
            let active = store.state.clock != nil
            let paused = active && store.state.clock?.resumedAt == nil
            Surface {
                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        Label("Rower live", systemImage: "antenna.radiowaves.left.and.right").font(.headline)
                        Spacer()
                        Circle().fill(fresh ? RowivoStyle.teal : RowivoStyle.clay).frame(width: 8, height: 8).accessibilityHidden(true)
                        Text(localized(!store.rower.isConnected ? "Disconnected" : fresh ? "Connected" : "Waiting for data"))
                            .font(.caption).foregroundStyle(RowivoStyle.muted)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 20) {
                        reading(active ? store.rowerRecording.map { metersText($0.measuredDistance) } ?? "—" : fresh ? snapshot.map { metersText($0.distance) } ?? "—" : "—",
                                label: active ? "Recorded distance" : "Device distance")
                        reading(fresh ? paceText(snapshot?.pace) : "—", label: "Pace /500 m")
                        reading(fresh ? snapshot?.strokeRate.map { $0.formatted() } ?? "—" : "—", label: "Strokes/min")
                        reading(fresh ? snapshot?.watts.map { $0.formatted() + " W" } ?? "—" : "—", label: "Power")
                        if fresh, let heartRate = snapshot?.heartRate {
                            reading(heartRate.formatted() + " bpm", label: "Heart rate via rower")
                        }
                    }
                    Text("Unavailable measurements are shown as —.").font(.caption).foregroundStyle(RowivoStyle.muted)
                    if paused { Text("Recording paused. Live device values may continue to change.").font(.caption).foregroundStyle(RowivoStyle.muted) }
                    if !fresh {
                        Text("No live data right now. Keep your rower awake and nearby. Recorded measurements are kept.")
                            .font(.caption).foregroundStyle(RowivoStyle.clay)
                    }
                    if store.rowerRecording?.hasGaps == true {
                        Text("This recording has gaps. Missing measurements are not estimated.").font(.caption).foregroundStyle(RowivoStyle.clay)
                    }
                }
            }.accessibilityIdentifier("pm5.live")
        }
    }
    private func reading(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(localized(label)).font(.caption).foregroundStyle(RowivoStyle.muted)
        }.accessibilityElement(children: .combine)
    }
}

struct RowerRecordingSummary: View {
    var recording: RowerRecording
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recorded with your rower", systemImage: "checkmark.circle.fill").font(.subheadline.bold()).foregroundStyle(RowivoStyle.teal)
            HStack(alignment: .top) {
                Metric(value: metersText(recording.measuredDistance), label: "Recorded distance")
                Metric(value: paceText(recording.averagePace), label: "Average /500 m")
            }
            Text(recording.deviceName).font(.caption).foregroundStyle(RowivoStyle.muted)
            if recording.hasGaps {
                Text("This recording has gaps. Missing measurements are not estimated.").font(.caption).foregroundStyle(RowivoStyle.clay)
            }
        }.accessibilityIdentifier("pm5.recording")
    }
}

struct RowerRecordingDetailView: View {
    var recording: RowerRecording
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Surface { RowerRecordingSummary(recording: recording) }
                Surface {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your rowing rhythm").font(.headline)
                        let showsPace = recording.samples.contains { $0.pace != nil }
                        Text(showsPace ? "Pace /500 m" : "Strokes/min").font(.caption).foregroundStyle(RowivoStyle.muted)
                        Chart(recording.samples) { sample in
                            if let value = showsPace ? sample.pace : sample.strokeRate {
                                PointMark(x: .value(localized("Minutes"), sample.workoutElapsed / 60), y: .value(localized(showsPace ? "Seconds /500 m" : "Strokes/min"), value))
                                    .foregroundStyle(RowivoStyle.teal).symbolSize(10)
                            }
                        }.chartXAxisLabel(localized("Minutes")).frame(height: 220)
                        Text("Dots show received measurements. Gaps are left empty.").font(.caption).foregroundStyle(RowivoStyle.muted)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Measured device time", value: recording.measuredTime.map { clockText(Int($0)) } ?? "—")
                        Text("Device time counts received changes in the rower’s timer, when available. Your Rowivo session also includes its guided pauses.")
                            .font(.caption).foregroundStyle(RowivoStyle.muted)
                    }
                }
            }.padding(22)
        }.rowivoScreen().navigationTitle("Rower recording").navigationBarTitleDisplayMode(.inline)
    }
}
