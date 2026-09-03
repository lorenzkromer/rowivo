import SwiftUI
import Charts
import RowivoCore

func paceText(_ seconds: Double?) -> String {
    guard let seconds, seconds.isFinite, seconds > 0 else { return "—" }
    return clockText(Int(seconds.rounded()))
}
func metersText(_ meters: Double) -> String { meters.formatted(.number.precision(.fractionLength(0))) + " m" }

struct PM5ConnectionCard: View {
    @Environment(RowivoStore.self) private var store
    @State private var showingDevice = false
    var body: some View {
        Button { showingDevice = true } label: {
            HStack(spacing: 14) {
                Image(systemName: store.pm5.isConnected ? "antenna.radiowaves.left.and.right" : "figure.rower")
                    .font(.title2).foregroundStyle(RowivoStyle.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized(store.pm5.state.rawValue)).font(.subheadline.bold())
                    Text(localized(store.pm5.isConnected ? "Live metrics from your rower" : "Concept2 · Bluetooth"))
                        .font(.caption).foregroundStyle(RowivoStyle.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }.padding(17).background(RowivoStyle.pale, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityIdentifier("pm5.open")
            .sheet(isPresented: $showingDevice) { PM5DeviceView() }
    }
}

struct PM5DeviceView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image(systemName: "figure.rower").font(.system(size: 52, weight: .light)).foregroundStyle(RowivoStyle.teal)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Concept2 PM5").font(.title2.bold())
                            Text(localized(store.pm5.state.rawValue)).font(.subheadline).foregroundStyle(RowivoStyle.muted)
                                .accessibilityIdentifier("pm5.status")
                        }
                    }.padding(.top, 10)
                    if store.pm5.isConnected {
                        PM5LivePanel()
                        if let name = store.pm5.selectedDevice?.name { Label(name, systemImage: "checkmark.circle.fill").font(.subheadline) }
                        Button("Disconnect PM5", role: .destructive) { store.pm5.disconnect() }.accessibilityIdentifier("pm5.disconnect")
                    } else {
                        Surface {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Ready in three steps").font(.headline)
                                Text("1. On your PM5, open Connect. If needed, disconnect another app first.")
                                Text("2. Find your PM5 below and select its name. The number matches your monitor.")
                                Text("3. Select Just Row on the PM5, start your session in Rowivo, then begin rowing.")
                            }.font(.subheadline).lineSpacing(3)
                        }
                        if store.pm5.isSimulator {
                            Label("A real iPhone is needed to connect to a PM5. Bluetooth is unavailable in the simulator.", systemImage: "iphone")
                                .font(.subheadline).foregroundStyle(RowivoStyle.muted).accessibilityIdentifier("pm5.simulator")
                        }
                        if [.poweredOff, .unauthorized].contains(store.pm5.state) {
                            Text("Enable Bluetooth and allow Rowivo to use it in iPhone settings.").font(.subheadline)
                            Button("Open iPhone settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                        if store.pm5.state == .failed {
                            Text("Keep your PM5 awake and nearby, open Connect again, then retry. Close other rowing apps if they are using the monitor.")
                                .font(.subheadline).foregroundStyle(RowivoStyle.clay)
                        }
                        if store.pm5.isBusy {
                            HStack { ProgressView(); Text(localized(store.pm5.state.rawValue)).font(.subheadline) }
                            Button("Cancel search") {
                                if store.pm5.state == .scanning { store.pm5.stopSearch() } else { store.pm5.disconnect() }
                            }
                        } else {
                            Button("Find my PM5") { store.pm5.search() }.buttonStyle(PrimaryButton()).accessibilityIdentifier("pm5.search")
                        }
                        ForEach(store.pm5.devices) { device in
                            Button { store.pm5.connect(device) } label: {
                                Surface {
                                    HStack {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                        Text(device.name).font(.headline)
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                    }
                                }
                            }.buttonStyle(.plain).disabled(store.pm5.state != .scanning && store.pm5.isBusy)
                        }
                        if store.pm5.devices.isEmpty && store.pm5.state == .idle {
                            Text("Your monitor will appear here while its Connect screen is open.").font(.caption).foregroundStyle(RowivoStyle.muted)
                        }
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your rower, your session").font(.headline)
                            Text("Rowivo guides the intervals on your iPhone. Set the PM5 to Just Row. Starting or pausing Rowivo does not control the monitor.")
                            Text("Only measurements received while your Rowivo session is running are recorded. Gaps are marked. PM5 measurements are stored locally and included in optional file exports.")
                        }.font(.caption).foregroundStyle(RowivoStyle.muted).lineSpacing(3)
                    }
                }.padding(22)
            }.rowivoScreen().navigationTitle("Your rowing machine").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onDisappear { store.pm5.stopSearch() }
        }
    }
}

struct PM5LivePanel: View {
    @Environment(RowivoStore.self) private var store
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = store.pm5.latest
            let fresh = store.pm5.isConnected && snapshot.map { timeline.date.timeIntervalSince($0.date) <= 5 } == true
            let active = store.state.clock != nil
            let paused = active && store.state.clock?.resumedAt == nil
            Surface {
                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        Label("PM5 live", systemImage: "antenna.radiowaves.left.and.right").font(.headline)
                        Spacer()
                        Circle().fill(fresh ? RowivoStyle.teal : RowivoStyle.clay).frame(width: 8, height: 8).accessibilityHidden(true)
                        Text(localized(!store.pm5.isConnected ? "Disconnected" : fresh ? "Connected" : "Waiting for data"))
                            .font(.caption).foregroundStyle(RowivoStyle.muted)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 20) {
                        reading(active ? store.pm5Recording.map { metersText($0.distance) } ?? "—" : fresh ? snapshot.map { metersText($0.general.distance) } ?? "—" : "—",
                                label: active ? "Recorded distance" : "PM5 distance")
                        reading(fresh ? paceText(snapshot?.pace) : "—", label: "Pace /500 m")
                        reading(fresh ? snapshot?.strokeRate.map { $0.formatted() } ?? "—" : "—", label: "Strokes/min")
                        reading(fresh ? snapshot?.watts.map { $0.formatted() + " W" } ?? "—" : "—", label: "Power")
                        if fresh, let heartRate = snapshot?.heartRate {
                            reading(heartRate.formatted() + " bpm", label: "Heart rate via PM5")
                        }
                    }
                    if paused { Text("Recording paused. PM5 live values may continue to change.").font(.caption).foregroundStyle(RowivoStyle.muted) }
                    if !fresh {
                        Text("No live data right now. Keep your PM5 awake and nearby. Recorded measurements are kept.")
                            .font(.caption).foregroundStyle(RowivoStyle.clay)
                    }
                    if store.pm5Recording?.hasGaps == true {
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

struct PM5RecordingSummary: View {
    var recording: PM5Recording
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recorded with PM5", systemImage: "checkmark.circle.fill").font(.subheadline.bold()).foregroundStyle(RowivoStyle.teal)
            HStack(alignment: .top) {
                Metric(value: metersText(recording.distance), label: "Recorded distance")
                Metric(value: paceText(recording.averagePace), label: "Average /500 m")
            }
            Text(recording.deviceName).font(.caption).foregroundStyle(RowivoStyle.muted)
            if recording.hasGaps {
                Text("This recording has gaps. Missing measurements are not estimated.").font(.caption).foregroundStyle(RowivoStyle.clay)
            }
        }.accessibilityIdentifier("pm5.recording")
    }
}

struct PM5RecordingDetailView: View {
    var recording: PM5Recording
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Surface { PM5RecordingSummary(recording: recording) }
                Surface {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your rowing rhythm").font(.headline)
                        Text("Pace /500 m").font(.caption).foregroundStyle(RowivoStyle.muted)
                        Chart(recording.samples) { sample in
                            if let pace = sample.pace {
                                PointMark(x: .value(localized("Minutes"), sample.workoutElapsed / 60), y: .value(localized("Seconds /500 m"), pace))
                                    .foregroundStyle(RowivoStyle.teal).symbolSize(10)
                            }
                        }.chartXAxisLabel(localized("Minutes")).frame(height: 220)
                        Text("Dots show received measurements. Gaps are left empty.").font(.caption).foregroundStyle(RowivoStyle.muted)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Measured PM5 time", value: clockText(Int(recording.rowingSeconds)))
                        Text("PM5 time counts received changes in the monitor's elapsed time. Your Rowivo session also includes its guided pauses.")
                            .font(.caption).foregroundStyle(RowivoStyle.muted)
                    }
                }
            }.padding(22)
        }.rowivoScreen().navigationTitle("PM5 recording").navigationBarTitleDisplayMode(.inline)
    }
}
