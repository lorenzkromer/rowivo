import SwiftUI
import RowivoCore

struct DashboardView: View {
    @Environment(RowivoStore.self) private var store
    var openPlan: () -> Void
    @State private var settings = false
    @State private var checkIn = false
    @State private var editingCompletion: WorkoutCompletion?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                        Text(String(format: String(localized: "Ready when you are, %@."), store.state.profile?.name ?? ""))
                            .font(.system(size: 35, weight: .bold, design: .rounded)).tracking(-1)
                    }.padding(.top, 8)
                    if store.state.clock != nil {
                        Button { store.showingWorkout = true } label: {
                            Label("Resume your session", systemImage: "play.circle.fill")
                        }.buttonStyle(PrimaryButton()).accessibilityIdentifier("workout.resume")
                    }
                    if store.needsCheckIn {
                        Surface {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("How are you feeling?", systemImage: "heart.text.clipboard").font(.headline)
                                Text("You reported discomfort last time. Check in before your next session.").font(.subheadline).foregroundStyle(RowivoStyle.muted)
                                Button("Check in") { checkIn = true }.font(.subheadline.bold())
                            }
                        }
                    } else if store.requiresRecentTrainingConfirmation && store.state.clock == nil {
                        Surface {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "leaf").font(.title2).foregroundStyle(RowivoStyle.teal)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("You trained recently.").font(.headline)
                                    Text("You can start another session. Rowivo will ask you to confirm first.")
                                        .font(.subheadline).foregroundStyle(RowivoStyle.muted)
                                }
                            }
                        }.accessibilityIdentifier("training.recent")
                    }
                    if let workout = store.nextWorkout {
                        workoutCard(workout)
                    } else {
                        Surface {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "square.and.pencil").font(.largeTitle).foregroundStyle(RowivoStyle.teal)
                                Text(localized(store.state.plan?.workouts.isEmpty == true ? "Build your first workout" : "Ready for your next workout?")).font(.title2.bold())
                                Text("Choose the steps, duration and effort in the planner.")
                                Button("Open planner", action: openPlan).buttonStyle(PrimaryButton()).accessibilityIdentifier("dashboard.plan")
                            }
                        }
                    }
                    if let log = store.latestCompletion {
                        Text("Last recorded session").font(.title3.bold())
                        RecordedWorkoutCard(log: log, context: "today") { editingCompletion = log }
                    }
                    JourneyLink()
                    RowerConnectionCard()
                    if let block = store.currentBlock { blockProgress(block) }
                    if store.nextWorkout != nil { Button(action: openPlan) {
                        Surface {
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: "slider.horizontal.3").font(.title2).foregroundStyle(RowivoStyle.teal)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("Adjust training").font(.headline)
                                    Text("Edit a workout, add intervals or arrange the next sessions.").font(.subheadline).foregroundStyle(RowivoStyle.muted)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right").font(.subheadline)
                            }
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("dashboard.plan") }
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                        Text("Your plan stays with you, even offline.")
                    }.font(.caption).foregroundStyle(RowivoStyle.muted).frame(maxWidth: .infinity)
                }.padding(.horizontal, 22).padding(.bottom, 28)
            }.rowivoScreen()
                .navigationDestination(for: UUID.self) { id in
                    if let workout = store.state.plan?.workouts.first(where: { $0.id == id }) {
                        WorkoutDetailView(workout: workout)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 8) { RowivoMark(); Text("rowivo").font(.system(size: 22, weight: .bold, design: .rounded)) }.padding(.horizontal, 12).padding(.vertical, 5).fixedSize().accessibilityIdentifier("dashboard.brand")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }
                            .accessibilityLabel("Settings").accessibilityIdentifier("settings.open")
                    }
                }
                .sheet(item: $editingCompletion) { RecordedWorkoutEditorView(completion: $0) }
                .sheet(isPresented: $settings) { SettingsView() }
                .sheet(isPresented: $checkIn) { CheckInView() }
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Eyebrow(text: "Next planned workout").foregroundStyle(RowivoStyle.lime)
                Spacer()
                if let block = store.currentBlock {
                    Text(blockText(block.week)).font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.white.opacity(0.12), in: Capsule())
                }
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.displayName).font(.system(size: 29, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                    Text("Find a pace that feels comfortable.").font(.subheadline).foregroundStyle(.white.opacity(0.73))
                }
                Spacer(minLength: 0)
                Image(systemName: "figure.rower").font(.system(size: 52, weight: .light)).foregroundStyle(RowivoStyle.lime).accessibilityHidden(true)
            }
            HStack(spacing: 20) {
                Label(durationText(workout.totalSeconds), systemImage: "clock")
                Label(workout.segments.contains { $0.intensity == .steady } ? localized("Steady") : localized("Easy"), systemImage: "waveform.path.ecg")
            }.font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.85))
            NavigationLink(value: workout.id) {
                HStack { Text("View workout"); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 19)
            }.buttonStyle(PrimaryButton(light: true)).accessibilityIdentifier("dashboard.workout")
        }.padding(24).foregroundStyle(.white)
            .background {
                ZStack(alignment: .bottom) {
                    RowivoStyle.ink
                    WaveArt().frame(height: 170).offset(y: 35).opacity(0.4)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 30))
    }

    private func blockProgress(_ block: TrainingBlock) -> some View {
        let ids = Set(store.state.completions.filter(\.finishedPlan).map(\.workoutID))
        let count = block.workouts.filter { ids.contains($0.id) }.count
        return Surface {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("This block").font(.headline)
                    Spacer()
                    Text("\(count)/\(block.workouts.count)").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(RowivoStyle.muted)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], spacing: 10) {
                    ForEach(Array(block.workouts.prefix(12).enumerated()), id: \.element.id) { index, workout in
                        HStack(spacing: 8) {
                            Image(systemName: ids.contains(workout.id) ? "checkmark.circle.fill" : "circle.dotted")
                            Text(String(format: String(localized: "Row %lld"), Int64(index + 1))).font(.caption.weight(.medium))
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(ids.contains(workout.id) ? RowivoStyle.lime : RowivoStyle.background, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
                if block.workouts.count > 12 { Text("Open the plan to see all workouts.").font(.caption).foregroundStyle(RowivoStyle.muted) }
            }
        }
    }
}

struct CheckInView: View {
    @Environment(RowivoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var resolved = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("You reported discomfort after your last session. If it persists, pause training and seek professional advice.")
                    Toggle("The discomfort has resolved and I feel ready to return.", isOn: $resolved)
                }
                Button("Save check-in") { store.checkIn(); dismiss() }.disabled(!resolved)
            }.rowivoScrollEdges().navigationTitle("Check in").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}
