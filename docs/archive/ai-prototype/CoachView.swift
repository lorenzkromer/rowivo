import SwiftUI
import RowivoCore

struct CoachView: View {
    @Environment(RowivoStore.self) private var store
    @Binding var draft: String
    @State private var settings = false
    @FocusState private var typing: Bool
    private var connected: Bool { store.hasAPIKey && store.state.hasAIConsent }
    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if store.state.messages.isEmpty { introduction }
                        ForEach(store.state.messages) { message in
                            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                                if message.role == .assistant {
                                    HStack(spacing: 5) { RowivoMark().scaleEffect(0.65).frame(width: 22, height: 22); Text("Rowivo Coach").font(.caption.weight(.semibold)) }
                                }
                                Text(message.text).font(.body).lineSpacing(4).textSelection(.enabled)
                                    .padding(17).foregroundStyle(message.role == .user ? .white : RowivoStyle.ink)
                                    .background(message.role == .user ? RowivoStyle.ink : .white, in: RoundedRectangle(cornerRadius: 22))
                                if message.failed && message.id == store.state.messages.last?.id {
                                    Button { store.send(message.text, retry: true) } label: { Label("Try again", systemImage: "arrow.clockwise") }
                                        .font(.caption.weight(.semibold)).disabled(store.isSending)
                                }
                            }.frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                                .padding(message.role == .user ? .leading : .trailing, 20).id(message.id)
                        }
                        if store.isSending {
                            HStack(spacing: 11) { SwiftUI.ProgressView().tint(RowivoStyle.teal); Text("Your coach is thinking…").font(.subheadline).foregroundStyle(RowivoStyle.muted) }
                                .padding(.vertical, 8)
                        }
                        if let pending = store.state.pendingAdjustment { proposal(pending) }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(22)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.state.messages.count) { _, _ in withAnimation { reader.scrollTo("bottom", anchor: .bottom) } }
                    .onChange(of: store.isSending) { _, _ in withAnimation { reader.scrollTo("bottom", anchor: .bottom) } }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .rowivoScreen().navigationTitle("Coach").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Coach settings") } }
            .sheet(isPresented: $settings) { SettingsView() }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 23) {
            ZStack {
                RoundedRectangle(cornerRadius: 23).fill(RowivoStyle.pale).frame(width: 76, height: 76)
                RowivoMark().scaleEffect(1.35)
            }.padding(.top, 20)
            VStack(alignment: .leading, spacing: 12) {
                Text("What's coming up?").font(.system(size: 35, weight: .bold, design: .rounded)).tracking(-1)
                Text("Discuss technique, reflect on a workout or adjust the next one. You decide which suggestions to apply.")
                    .foregroundStyle(RowivoStyle.muted).lineSpacing(4)
            }
            if !connected {
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Activate chat", systemImage: "key").font(.headline)
                        Text("Add your Anthropic API key and choose what to share. Your training plan works without it.")
                            .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                        Button("Set up connection") { settings = true }.font(.subheadline.bold()).accessibilityIdentifier("coach.connect")
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Start a conversation").foregroundStyle(RowivoStyle.muted)
                prompt("I have less time this week.")
                prompt("How can I improve my technique?")
                prompt("My last session felt hard.")
            }
        }
    }
    private func prompt(_ title: String) -> some View {
        Button { draft = localized(title); typing = true } label: {
            HStack { Text(localized(title)).font(.subheadline); Spacer(); Image(systemName: "arrow.up.left").font(.caption) }
                .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 17))
        }.buttonStyle(.plain)
    }

    private var composer: some View {
        VStack(spacing: 9) {
            if !connected && !store.state.messages.isEmpty {
                Button("Connect your coach") { settings = true }.font(.caption.bold())
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("What's on your mind?", text: $draft, axis: .vertical).lineLimit(1...5).focused($typing)
                    .padding(.vertical, 12).padding(.leading, 16).accessibilityIdentifier("coach.input")
                Button {
                    guard connected else { settings = true; return }
                    let message = draft; store.send(message)
                    if store.isSending { draft = ""; typing = false }
                } label: {
                    Image(systemName: "arrow.up").font(.headline).frame(width: 43, height: 43)
                        .background(RowivoStyle.ink, in: Circle()).foregroundStyle(.white)
                }.padding(5).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSending)
                    .opacity(draft.isEmpty || store.isSending ? 0.4 : 1).accessibilityLabel("Send message").accessibilityIdentifier("coach.send")
            }.background(.white, in: RoundedRectangle(cornerRadius: 27))
            Text("AI suggestions can be mistaken. Review changes before applying them.")
                .font(.system(size: 10)).foregroundStyle(RowivoStyle.muted).multilineTextAlignment(.center)
        }.padding(.horizontal, 18).padding(.vertical, 12).background(RowivoStyle.background)
    }

    private func proposal(_ pending: PendingAdjustment) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                Label("A change to consider", systemImage: "slider.horizontal.3").font(.headline)
                Text(adjustmentTitle(pending.adjustment)).font(.title3.weight(.semibold))
                Text(pending.adjustment.reason).font(.subheadline).foregroundStyle(RowivoStyle.muted)
                Text("Your current plan stays in place until you apply this change.").font(.caption).foregroundStyle(RowivoStyle.muted)
                Button("Apply change") { store.applyProposal() }.buttonStyle(PrimaryButton()).disabled(store.state.clock != nil || store.isSending)
                Button("Keep my plan") { store.dismissProposal() }.font(.subheadline).frame(maxWidth: .infinity)
            }
        }
    }
    private func adjustmentTitle(_ change: CoachAdjustment) -> String {
        switch change.action {
        case .shortenNext: String(format: String(localized: "Next session: %lld minutes"), Int64(change.value))
        case .easeNext: String(localized: "Make your next row easy")
        case .repeatLastBlock: String(localized: "Repeat your last training block")
        case .reduceFrequency: String(localized: "Two sessions per training block")
        }
    }
}
