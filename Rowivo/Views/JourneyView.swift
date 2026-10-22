import SwiftUI
import RowivoCore

struct JourneyLink: View {
    @Environment(RowivoStore.self) private var store
    var body: some View {
        NavigationLink { JourneyView() } label: {
            Surface {
                HStack(spacing: 16) {
                    Image(systemName: "sailboat.fill").font(.title).foregroundStyle(RowivoStyle.teal)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your rowing journey").font(.headline)
                        Text(localized(RowingJourney(completions: store.state.completions).next?.name ?? "Lake explored"))
                            .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
            }
        }.buttonStyle(.plain).accessibilityIdentifier("journey.open")
    }
}

struct JourneyView: View {
    @Environment(RowivoStore.self) private var store
    private var journey: RowingJourney { .init(completions: store.state.completions) }
    @State private var preview = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "A little further each time").foregroundStyle(RowivoStyle.teal)
                    Text("Your rowing journey").font(.largeTitle.bold())
                    Text("Quiet water. New places. Every measured meter brings you closer.")
                        .foregroundStyle(RowivoStyle.muted)
                }
                JourneyLandscape(meters: journey.meters, moving: false)
                    .frame(height: 290).clipShape(RoundedRectangle(cornerRadius: 26))
                    .accessibilityHidden(true)
                Surface {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Morning lake", systemImage: "water.waves").font(.headline)
                        JourneyProgress(journey: journey)
                        Divider()
                        ForEach(RowingJourney.stops) { stop in
                            let unlocked = journey.meters >= stop.meters
                            HStack(spacing: 14) {
                                Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.circle")
                                    .font(.title2).foregroundStyle(unlocked ? RowivoStyle.teal : RowivoStyle.muted)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(localized(stop.name)).font(.headline)
                                    Text(stop.meters.formatted(.number.precision(.fractionLength(0))) + " m")
                                        .font(.caption).foregroundStyle(RowivoStyle.muted)
                                }
                                Spacer()
                                if journey.next?.id == stop.id { Text("Next stop").font(.caption).foregroundStyle(RowivoStyle.teal) }
                            }.padding(.vertical, 5).accessibilityElement(children: .combine)
                                .accessibilityValue(localized(unlocked ? "Discovered" : "Locked"))
                        }
                    }
                }
                Button("Preview the landscape", systemImage: "play.circle") { preview = true }
                    .buttonStyle(PrimaryButton()).accessibilityIdentifier("journey.preview")
                Text("Saved device meters count, including earlier sessions and partial workouts. Deleting a recording recalculates the journey. Restored backups keep the same progress.")
                    .font(.footnote).foregroundStyle(RowivoStyle.muted)
                Text("Choose Landscape during your next workout. Without measured distance, your boat waits at the shore.")
                    .font(.footnote).foregroundStyle(RowivoStyle.muted)
            }.padding(22)
        }.rowivoScreen().navigationTitle("Journey").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $preview) { JourneyPreview() }
    }
}

struct JourneyProgress: View {
    let journey: RowingJourney
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(journey.meters.formatted(.number.precision(.fractionLength(0))) + " m").font(.title2.bold()).monospacedDigit()
                Spacer()
                Text("Measured journey distance").font(.caption).foregroundStyle(RowivoStyle.muted)
            }
            if let next = journey.next {
                ProgressView(value: journey.legProgress).tint(RowivoStyle.teal)
                Text(String(format: String(localized: "%@ m to %@"),
                            journey.remaining.formatted(.number.precision(.fractionLength(0))), localized(next.name)))
                    .font(.subheadline).foregroundStyle(RowivoStyle.muted)
            } else {
                Label("Lake explored", systemImage: "sparkles").foregroundStyle(RowivoStyle.teal)
                Text("All places discovered. Enjoy the water at your own pace.").font(.subheadline)
            }
        }.accessibilityElement(children: .combine).accessibilityIdentifier("journey.progress")
    }
}

/// Clearly separated demo. It never enters the store or creates a training recording.
private struct JourneyPreview: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var meters = 0.0
    @State private var running = true
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Landscape preview").font(.title.bold())
                    Text("Simulated meters. This preview does not save a workout or unlock places.")
                        .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                    JourneyLandscape(meters: meters, moving: running && scenePhase == .active)
                        .frame(height: 350).clipShape(RoundedRectangle(cornerRadius: 26)).accessibilityHidden(true)
                    JourneyProgress(journey: .init(meters: meters))
                    Button(running ? "Pause preview" : "Continue preview") { running.toggle() }
                        .buttonStyle(PrimaryButton()).accessibilityIdentifier("journey.preview.pause")
                    Button("Next place") {
                        meters = RowingJourney(meters: meters).next?.meters ?? 0
                    }.frame(minHeight: 44).accessibilityIdentifier("journey.preview.next")
                }.padding(22)
            }.rowivoScreen().navigationTitle("Preview").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("journey.preview.done") } }
                .task {
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                        if running && scenePhase == .active { meters += 1.25 }
                    }
                }
        }
    }
}

struct WorkoutJourneyPanel: View {
    @Environment(RowivoStore.self) private var store
    let paused: Bool
    let finished: Bool
    let date: Date
    private var saved: RowingJourney { .init(completions: store.state.completions) }
    private var journey: RowingJourney { saved.adding(store.rowerRecording?.measuredDistance) }
    private var hasFreshDistance: Bool {
        guard store.rower.isConnected, let sample = store.rowerRecording?.samples.last,
              sample.monitorDistance != nil else { return false }
        return (0...3).contains(date.timeIntervalSince(sample.date))
    }
    private var status: String {
        if finished { return "Session complete" }
        if paused { return "Paused" }
        return hasFreshDistance ? "Follow the water" : "Waiting for measured distance"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topLeading) {
                JourneyLandscape(meters: journey.meters, moving: !paused && !finished && hasFreshDistance)
                    .frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 26)).accessibilityHidden(true)
                Text(localized(status)).font(.caption.weight(.semibold))
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule()).padding(16)
            }
            JourneyProgress(journey: journey)
            if journey.discovered.count > saved.discovered.count {
                Label("New place reached", systemImage: "sparkles").font(.headline).foregroundStyle(RowivoStyle.teal)
            }
            Text("Journey progress is kept when you save this session.").font(.caption).foregroundStyle(RowivoStyle.muted)
        }.accessibilityIdentifier("journey.workout")
    }
}

/// Vector landscape: distance moves the banks and trees; time animates only ripples.
/// Drawing is read-only and uses no external images, network, or persistent game ledger.
struct JourneyLandscape: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var meters: Double
    var moving: Bool
    var body: some View {
        JourneyLandscapeDrawing(meters: meters, moving: moving && scenePhase == .active)
            .animation(reduceMotion || !moving || scenePhase != .active ? nil : .linear(duration: 0.8), value: meters)
    }
}

private struct JourneyLandscapeDrawing: View, Animatable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var meters: Double
    var moving: Bool
    nonisolated var animatableData: Double {
        get { meters }
        set { meters = newValue }
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !moving || reduceMotion || scenePhase != .active)) { timeline in
            Canvas { context, size in
                draw(context: &context, size: size, time: reduceMotion || !moving ? 0 : timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }
    private func draw(context: inout GraphicsContext, size: CGSize, time: Double) {
        let w = size.width, h = size.height
        let sky = Color(red: 0.86, green: 0.92, blue: 0.88)
        let mist = Color(red: 0.96, green: 0.91, blue: 0.75)
        let water = Color(red: 0.28, green: 0.57, blue: 0.55)
        let dark = Color(red: 0.12, green: 0.30, blue: 0.27)
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .linearGradient(.init(colors: [sky, mist]), startPoint: .zero, endPoint: .init(x: 0, y: h)))
        context.fill(Path(ellipseIn: .init(x: w * 0.69, y: h * 0.10, width: 40, height: 40)), with: .color(.init(red: 1, green: 0.95, blue: 0.79)))
        // Layered mountain silhouettes, softened with atmospheric perspective.
        for layer in 0..<3 {
            let base = h * (0.36 + Double(layer) * 0.045)
            var mountain = Path(); mountain.move(to: .init(x: 0, y: base))
            for i in 0...16 {
                let x = w * Double(i) / 16
                let wave = sin(Double(i) * 0.87 + Double(layer) * 2.1)
                mountain.addLine(to: .init(x: x, y: base - h * (0.045 + 0.09 * abs(wave))))
            }
            mountain.addLine(to: .init(x: w, y: h * 0.53)); mountain.addLine(to: .init(x: 0, y: h * 0.53)); mountain.closeSubpath()
            context.fill(mountain, with: .color(dark.opacity(0.13 + Double(layer) * 0.10)))
        }
        let horizon = h * 0.43
        context.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
                     with: .linearGradient(.init(colors: [Color(red: 0.65, green: 0.77, blue: 0.66), water, dark]), startPoint: .init(x: 0, y: horizon), endPoint: .init(x: 0, y: h * 1.4)))
        var glow = Path(); glow.move(to: .init(x: w * 0.72, y: horizon)); glow.addLine(to: .init(x: w * 0.92, y: h)); glow.addLine(to: .init(x: w * 0.57, y: h)); glow.closeSubpath()
        context.fill(glow, with: .color(mist.opacity(0.12)))
        for side in 0...1 {
            var bank = Path()
            let edge: CGFloat = side == 0 ? 0 : w
            let sign: CGFloat = side == 0 ? 1 : -1
            bank.move(to: .init(x: edge, y: horizon - 4))
            bank.addLine(to: .init(x: w * 0.5 + sign * -12, y: horizon))
            bank.addCurve(to: .init(x: edge + sign * w * 0.10, y: h), control1: .init(x: edge + sign * w * 0.08, y: h * 0.52), control2: .init(x: edge + sign * w * 0.30, y: h * 0.74))
            bank.addLine(to: .init(x: edge, y: h)); bank.closeSubpath()
            context.fill(bank, with: .color(side == 0 ? Color(red: 0.27, green: 0.43, blue: 0.32) : Color(red: 0.36, green: 0.49, blue: 0.33)))
            // Trees grow toward the camera only as measured distance increases.
            for i in 0..<12 {
                let depth = (Double(i) / 12 + (reduceMotion ? 0 : meters / 240).truncatingRemainder(dividingBy: 1)).truncatingRemainder(dividingBy: 1)
                let perspective = depth * depth
                let y = horizon + (h - horizon) * perspective
                let x = edge + sign * (w * 0.42 * (1 - depth) + sin(Double(i) * 7) * w * 0.035)
                let treeH = 9 + perspective * h * 0.31
                let treeW = treeH * 0.47
                var tree = Path(); tree.move(to: .init(x: x, y: y - treeH))
                tree.addLine(to: .init(x: x - treeW / 2, y: y)); tree.addLine(to: .init(x: x + treeW / 2, y: y)); tree.closeSubpath()
                context.fill(tree, with: .color(dark.opacity(0.52 + depth * 0.4)))
            }
        }
        // The next landing grows into view near an actual distance milestone.
        let journey = RowingJourney(meters: meters)
        if let next = journey.next {
            let approach = max(0.06, 1 - min(1, journey.remaining / 350))
            let depth = reduceMotion ? 0.16 : approach * approach
            let landingY = horizon + (h - horizon) * depth * 0.8
            let landingX = w * (0.64 + depth * 0.25)
            let dockWidth = 12 + depth * 52
            let dockHeight = 3 + depth * 9
            let dock = CGRect(x: landingX - dockWidth, y: landingY, width: dockWidth, height: dockHeight)
            context.fill(Path(dock), with: .color(Color(red: 0.67, green: 0.49, blue: 0.29)))
            var post = Path(); post.move(to: .init(x: landingX - dockWidth + 3, y: landingY + dockHeight + 5))
            post.addLine(to: .init(x: landingX - dockWidth + 3, y: landingY - 9 - depth * 10))
            context.stroke(post, with: .color(dark), lineWidth: 2)
            if next.id == 3 {
                context.fill(Path(ellipseIn: .init(x: w * 0.42, y: horizon + 7, width: 45, height: 7)), with: .color(dark.opacity(0.5)))
            }
        }
        // Gentle, horizontal ripple highlights avoid rapid camera motion.
        for i in 0..<23 {
            let depth = Double(i + 1) / 24
            let y = horizon + (h - horizon) * depth * depth
            let x = w * (0.35 + 0.32 * (0.5 + 0.5 * sin(Double(i) * 4.9 + time * 0.45)))
            let length = 5 + 29 * depth
            var ripple = Path(); ripple.move(to: .init(x: x, y: y)); ripple.addLine(to: .init(x: x + length, y: y))
            context.stroke(ripple, with: .color(mist.opacity(0.13 + 0.12 * depth)), lineWidth: 1)
        }
        // A wooden rowing shell anchors the view; the shore conveys forward movement.
        let cx = w * 0.53, top = h * 0.69, bottom = h * 0.96
        var wake = Path()
        wake.move(to: .init(x: cx - 12, y: h * 0.83)); wake.addQuadCurve(to: .init(x: cx - 42, y: h), control: .init(x: cx - 23, y: h * 0.91))
        wake.move(to: .init(x: cx + 12, y: h * 0.83)); wake.addQuadCurve(to: .init(x: cx + 42, y: h), control: .init(x: cx + 23, y: h * 0.91))
        context.stroke(wake, with: .color(mist.opacity(moving ? 0.45 : 0.12)), lineWidth: 1.5)
        var hull = Path(); hull.move(to: .init(x: cx, y: top))
        hull.addQuadCurve(to: .init(x: cx + 11, y: bottom - 8), control: .init(x: cx + 22, y: h * 0.84))
        hull.addQuadCurve(to: .init(x: cx - 11, y: bottom - 8), control: .init(x: cx, y: bottom + 8))
        hull.addQuadCurve(to: .init(x: cx, y: top), control: .init(x: cx - 22, y: h * 0.84))
        context.fill(hull, with: .color(Color(red: 0.79, green: 0.61, blue: 0.37)))
        var deck = Path(); deck.move(to: .init(x: cx, y: top + 9)); deck.addLine(to: .init(x: cx, y: bottom - 12))
        context.stroke(deck, with: .color(mist.opacity(0.6)), lineWidth: 1)
        let oarShift = moving && !reduceMotion ? sin(time * 2) * 7 : 0
        for side in [-1.0, 1.0] {
            var oar = Path(); oar.move(to: .init(x: cx, y: h * 0.85))
            oar.addLine(to: .init(x: cx + side * w * 0.17, y: h * 0.90 + oarShift))
            context.stroke(oar, with: .color(mist), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }
}
