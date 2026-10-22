import SwiftUI
import RowivoCore

enum RowivoStyle {
    static let background = Color(red: 0.965, green: 0.965, blue: 0.94)
    static let ink = Color(red: 0.07, green: 0.20, blue: 0.20)
    static let teal = Color(red: 0.16, green: 0.40, blue: 0.35)
    static let muted = Color(red: 0.39, green: 0.46, blue: 0.43)
    static let lime = Color(red: 0.84, green: 0.94, blue: 0.65)
    static let pale = Color(red: 0.89, green: 0.93, blue: 0.87)
    static let clay = Color(red: 0.69, green: 0.37, blue: 0.24)
}

struct PrimaryButton: ButtonStyle {
    var light = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(light ? RowivoStyle.lime : RowivoStyle.ink, in: RoundedRectangle(cornerRadius: 19))
            .foregroundStyle(light ? RowivoStyle.ink : .white)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 26))
    }
}

struct Eyebrow: View {
    var text: LocalizedStringKey
    var body: some View { Text(text).font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.8).textCase(.uppercase) }
}

struct RowivoMark: View {
    var color: Color = RowivoStyle.ink
    var body: some View {
        ZStack {
            Capsule().fill(color).frame(width: 6, height: 25).rotationEffect(.degrees(40)).offset(x: -6, y: -2)
            Capsule().fill(color).frame(width: 6, height: 25).rotationEffect(.degrees(40)).offset(x: 5, y: 2)
        }.frame(width: 32, height: 32).accessibilityHidden(true)
    }
}

struct WaveArt: View {
    var color: Color = RowivoStyle.lime
    var body: some View {
        Canvas { context, size in
            for line in 0..<7 {
                var path = Path()
                let y = size.height * 0.28 + CGFloat(line) * 17
                path.move(to: CGPoint(x: -15, y: y))
                path.addCurve(to: CGPoint(x: size.width + 20, y: y - 30),
                              control1: CGPoint(x: size.width * 0.42, y: y - 90),
                              control2: CGPoint(x: size.width * 0.58, y: y + 85))
                context.stroke(path, with: .color(color.opacity(0.12 + Double(line) * 0.07)), lineWidth: 1.6)
            }
        }.accessibilityHidden(true)
    }
}

struct Metric: View {
    var value: String
    var label: LocalizedStringKey
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(RowivoStyle.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SegmentBar: View {
    var workout: Workout
    var body: some View {
        GeometryReader { proxy in
            let gap = min(3, proxy.size.width / CGFloat(max(1, workout.segments.count) * 4))
            HStack(spacing: gap) {
                ForEach(workout.segments) { segment in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(segment.kind == .work ? RowivoStyle.teal : RowivoStyle.pale)
                        .frame(width: max(0, (proxy.size.width - CGFloat(workout.segments.count - 1) * gap) * CGFloat(segment.seconds) / CGFloat(max(1, workout.totalSeconds))))
                }
            }
        }.frame(height: 22).accessibilityLabel("Workout segments")
    }
}

extension View {
    func rowivoScreen() -> some View {
        self.background(RowivoStyle.background).foregroundStyle(RowivoStyle.ink)
            .rowivoScrollEdges()
    }

    /// Let system bars blur scrolling content instead of covering it with a solid fill.
    @ViewBuilder func rowivoScrollEdges() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .vertical)
        } else {
            self.toolbarBackground(.regularMaterial, for: .navigationBar)
        }
    }

    /// Register custom controls with the native scroll-edge effect and safe-area layout.
    @ViewBuilder func rowivoBottomBar<Bar: View>(@ViewBuilder content: () -> Bar) -> some View {
        if #available(iOS 26.0, *) {
            self.safeAreaBar(edge: .bottom, spacing: 0, content: content)
        } else {
            self.safeAreaInset(edge: .bottom, spacing: 0) {
                content().background(.bar)
            }
        }
    }
}
