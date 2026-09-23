import SwiftUI

struct FinishWorkoutSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var effort: Double = 7
    @State private var notes = ""
    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let session = store.activeSession {
                        hero(session)
                        stats(session)
                        effortCard
                        notesCard
                        actions(session)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) {
                    // Closing the workout cover also dismisses this sheet.
                    store.discardActiveWorkout()
                    RestNotifier.cancel()
                }
            } message: {
                Text("Logged sets from this session will be lost.")
            }
        }
    }

    private func hero(_ session: WorkoutSession) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.accentGradient).frame(width: 84, height: 84)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 20)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.black)
            }
            Text(session.completedSetCount > 0 ? "Great work!" : "Nothing logged yet")
                .font(.system(.title).weight(.semibold))
            Text(session.completedSetCount > 0
                 ? "You completed \(session.completedSetCount) of \(session.totalSetCount) sets."
                 : "Tick off at least one set to save this workout.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 8)
    }

    private func stats(_ session: WorkoutSession) -> some View {
        let metric = store.profile.useMetric
        return HStack(spacing: 12) {
            StatTile(value: Format.minutes(session.duration), label: "Duration", symbol: "clock.fill", tint: Theme.blue)
            StatTile(value: Format.compact(WeightUnit.display(session.totalVolumeKg, metric: metric)),
                     label: "Volume (\(WeightUnit.label(metric: metric)))", symbol: "scalemass.fill", tint: Theme.accent)
            StatTile(value: "\(session.completedSetCount)", label: "Sets", symbol: "square.stack.3d.up.fill", tint: Theme.orange)
        }
    }

    private var effortCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("How hard was it?").font(.headline)
                Spacer()
                Text("\(Int(effort))/10 · \(effortLabel)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(effortColor)
            }
            Slider(value: $effort, in: 1...10, step: 1)
                .tint(effortColor)
            Text("Your coach uses this to decide when to push harder or back off.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .cardStyle()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes").font(.headline)
            TextField("How did it feel? Any pain or wins?", text: $notes, axis: .vertical)
                .lineLimit(2...5)
        }
        .cardStyle()
    }

    private func actions(_ session: WorkoutSession) -> some View {
        VStack(spacing: 12) {
            Button {
                store.finishActiveWorkout(effort: Int(effort), notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
                RestNotifier.cancel()
                Haptics.success()
            } label: {
                Label("Save workout", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(session.completedSetCount == 0)
            .opacity(session.completedSetCount == 0 ? 0.4 : 1)

            Button(role: .destructive) {
                confirmDiscard = true
            } label: {
                Text("Discard workout")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.danger)
            }
            .padding(.top, 4)
        }
    }

    private var effortLabel: String {
        switch Int(effort) {
        case ...3: return "Easy"
        case 4...6: return "Moderate"
        case 7...8: return "Hard"
        default: return "All-out"
        }
    }

    private var effortColor: Color {
        switch Int(effort) {
        case ...3: return Theme.accentAlt
        case 4...6: return Theme.accent
        case 7...8: return Theme.orange
        default: return Theme.danger
        }
    }
}
