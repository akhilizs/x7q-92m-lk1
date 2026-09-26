import SwiftUI

/// Shown after a workout is saved: records, newly earned badges and a share card.
struct WorkoutSummaryView: View {
    let completed: CompletedWorkout
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let session = completed.session
        let metric = store.profile.useMetric
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text("WORKOUT SAVED")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text(session.name)
                            .font(.system(size: 30, weight: .medium))
                            .italic()
                            .multilineTextAlignment(.center)
                        if completed.streak > 1 {
                            Label("\(completed.streak)-week streak", systemImage: "flame.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.orange)
                        }
                    }
                    .padding(.top, 8)

                    HStack(spacing: 12) {
                        StatTile(value: Format.minutes(session.duration), label: "Duration", symbol: "clock.fill", tint: Theme.blue)
                        StatTile(value: Format.compact(WeightUnit.display(session.totalVolumeKg, metric: metric)),
                                 label: "Volume (\(WeightUnit.label(metric: metric)))", symbol: "scalemass.fill", tint: Theme.accent)
                        StatTile(value: "\(session.completedSetCount)", label: "Sets", symbol: "square.stack.3d.up.fill", tint: Theme.orange)
                    }

                    if !completed.newBadges.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(completed.newBadges.count == 1 ? "Badge unlocked" : "\(completed.newBadges.count) badges unlocked")
                                .font(.headline)
                            ForEach(completed.newBadges) { badge in
                                HStack(spacing: 14) {
                                    BadgeMedal(badge: badge, earned: true, size: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(badge.title).font(.system(size: 17, weight: .semibold))
                                        Text(badge.detail).font(.caption).foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }

                    if !completed.records.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("New personal records").font(.headline)
                            ForEach(completed.records, id: \.self) { id in
                                Label(ExerciseLibrary.name(for: id), systemImage: "trophy.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.sand)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }

                    VStack(spacing: 14) {
                        WorkoutShareCard(session: session, records: completed.records, streak: completed.streak, metric: metric)
                            .scaleEffect(0.62)
                            .frame(width: 360 * 0.62, height: 640 * 0.62)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                            .accessibilityHidden(true)
                        ShareWorkoutButton(session: session, records: completed.records, streak: completed.streak, metric: metric)
                    }
                }
                .padding(20)
            }
            .appBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(.headline)
                }
            }
        }
    }
}

/// A 9:16 story image summarising a workout.
struct WorkoutShareCard: View {
    let session: WorkoutSession
    let records: [String]
    let streak: Int
    let metric: Bool

    var body: some View {
        let unit = WeightUnit.label(metric: metric)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                    Text("FORGEFIT")
                }
                .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(Format.dayMonth.string(from: session.startedAt).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text("WORKOUT COMPLETE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text(session.name)
                .font(.system(size: 38, weight: .medium))
                .italic()
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.bottom, 14)
            HStack(spacing: 8) {
                pill(Format.minutes(session.duration), "time", Theme.sky)
                pill(Format.compact(WeightUnit.display(session.totalVolumeKg, metric: metric)), unit, Theme.sand)
                pill("\(session.completedSetCount)", "sets", Theme.sage)
            }
            .padding(.bottom, 16)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(topLifts.prefix(4), id: \.id) { lift in
                    HStack(spacing: 8) {
                        Text(lift.name)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        if records.contains(lift.exerciseID) {
                            Text("PR")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.sand))
                        }
                        Spacer()
                        Text(best(lift, unit: unit))
                            .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.1)))
            if streak > 1 {
                Label("\(streak)-week streak", systemImage: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                    .padding(.top, 14)
            }
            Spacer().frame(height: 26)
            Text("Tracked with ForgeFit")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(width: 360, height: 640)
        .background(
            ZStack {
                Color.black
                Image("HeroAthlete")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 360, height: 640)
                    .clipped()
                    .opacity(0.55)
                LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.6), .black.opacity(0.95)],
                               startPoint: .top, endPoint: .bottom)
            }
        )
    }

    private var topLifts: [LoggedExercise] {
        session.exercises.filter { !$0.completedSets.isEmpty }
    }

    private func best(_ exercise: LoggedExercise, unit: String) -> String {
        switch exercise.tracking {
        case .weightReps:
            guard let set = exercise.completedSets.max(by: {
                LoggedExercise.estimatedOneRepMax(weight: $0.weightKg, reps: $0.reps)
                    < LoggedExercise.estimatedOneRepMax(weight: $1.weightKg, reps: $1.reps)
            }) else { return "" }
            return "\(WeightUnit.format(set.weightKg, metric: metric)) \(unit) × \(set.reps)"
        case .reps:
            return "\(exercise.completedSets.map(\.reps).max() ?? 0) reps"
        case .time:
            let seconds = exercise.completedSets.map(\.seconds).max() ?? 0
            return seconds >= 120 ? "\(seconds / 60) min" : "\(seconds) s"
        }
    }

    private func pill(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 20, weight: .semibold).monospacedDigit())
            Text(label).font(.system(size: 11, weight: .medium)).opacity(0.7)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color))
    }
}

/// Renders the share card to an image and offers it to the share sheet.
struct ShareWorkoutButton: View {
    let session: WorkoutSession
    let records: [String]
    let streak: Int
    let metric: Bool
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview("\(session.name) workout", image: image)) {
                    Label("Share workout", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                ProgressView()
                    .frame(height: 56)
            }
        }
        .task(id: session.id) { image = render() }
    }

    @MainActor
    private func render() -> Image? {
        let card = WorkoutShareCard(session: session, records: records, streak: streak, metric: metric)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
