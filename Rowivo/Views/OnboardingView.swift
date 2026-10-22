import SwiftUI
import RowivoCore

struct OnboardingView: View {
    @Environment(RowivoStore.self) private var store
    @State private var showProfile = false
    @State private var storage = false
    @State private var name = ""
    @State private var goal = TrainingGoal.routine
    @State private var experience = Experience.beginner
    @State private var sessions = 3
    @State private var minutes = 30
    @State private var useTemplate = false
    var body: some View {
        NavigationStack {
            Group {
                if showProfile { profileForm }
                else { welcome }
            }.rowivoScreen()
                .sheet(isPresented: $storage) { StorageView() }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                RowivoMark()
                Text("rowivo").font(.system(size: 27, weight: .bold, design: .rounded))
            }.padding(.top, 18)
            Spacer(minLength: 20)
            ZStack {
                RoundedRectangle(cornerRadius: 40).fill(RowivoStyle.ink)
                WaveArt().clipShape(RoundedRectangle(cornerRadius: 40))
                VStack(spacing: 24) {
                    Image(systemName: "figure.rower").font(.system(size: 85, weight: .light)).foregroundStyle(RowivoStyle.lime)
                    HStack(spacing: 7) {
                        Circle().fill(RowivoStyle.lime).frame(width: 6, height: 6)
                        Eyebrow(text: "Made for your pace").foregroundStyle(.white)
                    }
                }
            }.frame(height: 260)
            Spacer(minLength: 24)
            Text("Your rhythm.\nYour progress.").font(.system(size: 43, weight: .bold, design: .rounded)).tracking(-1.8).fixedSize(horizontal: false, vertical: true)
            Text("Build your workouts, connect your rower and follow your progress.")
                .font(.body).foregroundStyle(RowivoStyle.muted).lineSpacing(4).padding(.top, 16)
            Spacer(minLength: 24)
            Button { withAnimation { showProfile = true } } label: {
                HStack { Text("Let's get started"); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 22)
            }.buttonStyle(PrimaryButton()).accessibilityIdentifier("onboarding.start")
            Button("Restore existing training") { storage = true }.font(.caption.weight(.medium)).foregroundStyle(RowivoStyle.muted)
                .frame(maxWidth: .infinity).padding(.top, 16).padding(.bottom, 12)
                .accessibilityIdentifier("onboarding.restore")
        }.padding(.horizontal, 26)
    }

    private var profileForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Set your starting point").font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Start with an empty plan and build workouts that fit your day.").foregroundStyle(RowivoStyle.muted)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What should we call you?").font(.headline)
                        TextField("Your name", text: $name).textContentType(.givenName).submitLabel(.done)
                            .padding(14).background(RowivoStyle.background, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("profile.name")
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("What brings you here?").font(.headline)
                    ForEach(TrainingGoal.allCases, id: \.self) { value in
                        Button { goal = value } label: {
                            HStack {
                                Image(systemName: value == .routine ? "calendar" : value == .fitness ? "heart" : "arrow.up.right")
                                    .frame(width: 28)
                                Text(localized(value.rawValue)).font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: goal == value ? "checkmark.circle.fill" : "circle")
                            }.padding(17).background(goal == value ? RowivoStyle.pale : .white, in: RoundedRectangle(cornerRadius: 17))
                        }.buttonStyle(.plain)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Training preferences").font(.headline)
                        Picker("Rowing experience", selection: $experience) {
                            ForEach(Experience.allCases, id: \.self) { Text(localized($0.rawValue)).tag($0) }
                        }.pickerStyle(.menu)
                        Divider()
                        Toggle("Use the eight-block starter template", isOn: $useTemplate).accessibilityIdentifier("profile.template")
                        if useTemplate {
                        Stepper(value: $sessions, in: 2...3) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sessions per block").font(.subheadline)
                                Text(sessions.formatted()).font(.title2.bold())
                            }
                        }
                        Text("Aim for a block each week, with a rest day between sessions. It's fine to take longer.")
                            .font(.caption).foregroundStyle(RowivoStyle.muted)
                        }
                        Divider()
                        Picker("Time per session", selection: $minutes) {
                            ForEach([15, 20, 25, 30, 40, 50, 60], id: \.self) { Text(minuteText($0)).tag($0) }
                        }.pickerStyle(.menu)
                        Text("A starting duration for new workouts. You can change every step later.").font(.caption).foregroundStyle(RowivoStyle.muted)
                    }
                }
                Text("Start comfortably. If you have health concerns, get professional advice before training.")
                    .font(.footnote).foregroundStyle(RowivoStyle.muted)
                Button("Start planning") {
                    store.createProfile(.init(name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)), goal: goal,
                                              experience: experience, sessionsPerWeek: sessions, sessionMinutes: minutes), useTemplate: useTemplate)
                }.buttonStyle(PrimaryButton()).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                    .accessibilityIdentifier("profile.create")
            }.padding(24)
        }.scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showProfile = false } label: { Image(systemName: "arrow.left") }.accessibilityLabel("Back") }
                ToolbarItem(placement: .principal) { Text("Your first step").font(.subheadline.weight(.semibold)) }
            }
    }
}
