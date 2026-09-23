import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(AppStore.self) private var store

    @State private var restEnd: Date?
    @State private var restTotal = 0
    @State private var showPicker = false
    @State private var showFinish = false

    private var sessionBinding: Binding<WorkoutSession> {
        Binding(
            get: { store.activeSession ?? WorkoutSession(name: "", exercises: []) },
            set: { store.activeSession = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(sessionBinding.exercises) { $exercise in
                            ExerciseLogCard(
                                exercise: $exercise,
                                previous: store.previousSets(for: exercise.exerciseID),
                                metric: store.profile.useMetric,
                                onCompleteSet: { startRest(seconds: exercise.restSeconds, after: exercise.name) },
                                onRemove: { remove(exerciseID: exercise.id) }
                            )
                        }
                        addExerciseButton
                        if store.activeSession?.exercises.isEmpty ?? true {
                            Text("Add exercises to start logging sets.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, restEnd == nil ? 40 : 130)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .appBackground()
            .overlay(alignment: .bottom) {
                if let restEnd {
                    RestTimerBar(end: restEnd, total: restTotal,
                                 onAdjust: { adjustRest(by: $0) },
                                 onSkip: { skipRest() })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: restEnd)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .font(.headline)
                }
            }
            .task(id: restEnd) {
                guard let end = restEnd else { return }
                let interval = end.timeIntervalSinceNow
                if interval > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                guard !Task.isCancelled, restEnd == end else { return }
                Haptics.success()
                restEnd = nil
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView(title: "Add to Workout", equipment: store.profile.equipment) { exercises in
                    for ex in exercises {
                        store.activeSession?.exercises.append(store.makeLoggedExercise(for: ex))
                    }
                }
            }
            .sheet(isPresented: $showFinish) {
                FinishWorkoutSheet()
                    .environment(store)
            }
            .onAppear { RestNotifier.requestAuthorization() }
        }
    }

    private var topBar: some View {
        let session = store.activeSession
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    store.isWorkoutPresented = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.surfaceRaised))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Minimize workout")

                VStack(spacing: 2) {
                    Text(session?.name ?? "Workout")
                        .font(.system(.headline).weight(.semibold))
                        .lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(Format.duration(session?.duration ?? 0))
                            .font(.system(.subheadline).weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.accent)
                    }
                }
                .frame(maxWidth: .infinity)

                Button {
                    dismissKeyboard()
                    showFinish = true
                } label: {
                    Text("Finish")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Capsule().fill(Theme.accentGradient))
                }
                .buttonStyle(PressableStyle())
            }
            HStack(spacing: 10) {
                ProgressBar(value: session?.progress ?? 0)
                Text("\(session?.completedSetCount ?? 0)/\(session?.totalSetCount ?? 0) sets")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.background.opacity(0.6))
    }

    private var addExerciseButton: some View {
        Button {
            showPicker = true
        } label: {
            Label("Add exercise", systemImage: "plus")
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func remove(exerciseID: UUID) {
        withAnimation {
            store.activeSession?.exercises.removeAll { $0.id == exerciseID }
        }
    }

    private func startRest(seconds: Int, after name: String) {
        guard seconds > 0 else { return }
        restTotal = seconds
        restEnd = Date().addingTimeInterval(TimeInterval(seconds))
        RestNotifier.schedule(after: seconds, next: nextUpName(after: name))
    }

    private func adjustRest(by delta: Int) {
        guard let end = restEnd else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(delta))
        let remaining = Int(newEnd.timeIntervalSinceNow.rounded())
        if remaining <= 0 {
            skipRest()
            return
        }
        restTotal = max(restTotal + delta, remaining)
        restEnd = newEnd
        RestNotifier.schedule(after: remaining, next: "")
        Haptics.tap()
    }

    private func skipRest() {
        restEnd = nil
        RestNotifier.cancel()
    }

    private func nextUpName(after name: String) -> String {
        guard let session = store.activeSession else { return name }
        if let current = session.exercises.first(where: { $0.name == name }),
           current.sets.contains(where: { !$0.completed }) {
            return current.name
        }
        return session.exercises.first { ex in ex.sets.contains { !$0.completed } }?.name ?? ""
    }
}

// MARK: - Exercise card

struct ExerciseLogCard: View {
    @Binding var exercise: LoggedExercise
    let previous: [LoggedSet]
    let metric: Bool
    let onCompleteSet: () -> Void
    let onRemove: () -> Void

    @State private var showCue = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if showCue, let cue = exercise.exercise?.cue {
                Text(cue)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .transition(.opacity)
            }
            if !exercise.notes.isEmpty {
                Label(exercise.notes, systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accentAlt)
            }
            columnHeader
            VStack(spacing: 8) {
                ForEach($exercise.sets) { $set in
                    let number = (exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1
                    SetRow(number: number,
                           set: $set,
                           tracking: exercise.tracking,
                           previous: number - 1 < previous.count ? previous[number - 1] : nil,
                           metric: metric,
                           onToggle: { toggle(setID: set.id) })
                }
            }
            HStack(spacing: 10) {
                Button {
                    addSet()
                } label: {
                    Label("Add set", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.surfaceRaised))
                }
                .buttonStyle(PressableStyle())
                if exercise.sets.count > 1 {
                    Button {
                        withAnimation { _ = exercise.sets.popLast() }
                        Haptics.tap()
                    } label: {
                        Label("Remove set", systemImage: "minus")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Theme.surfaceRaised))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .cardStyle(padding: 14, radius: 22)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            let muscle = exercise.exercise?.primary ?? .fullBody
            Image(systemName: muscle.symbol)
                .font(.headline)
                .foregroundStyle(Theme.color(for: muscle))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Theme.color(for: muscle).opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(.headline).weight(.semibold))
                Text(targetText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Menu {
                Button {
                    withAnimation { showCue.toggle() }
                } label: { Label(showCue ? "Hide form cue" : "Show form cue", systemImage: "info.circle") }
                Button(role: .destructive, action: onRemove) {
                    Label("Remove exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surfaceRaised))
            }
            .accessibilityLabel("Exercise options")
        }
    }

    private var targetText: String {
        let low = exercise.targetRepsLow, high = exercise.targetRepsHigh
        let range = low == high ? "\(low)" : "\(low)–\(high)"
        let unit = exercise.tracking == .time ? (high >= 120 ? "" : " s") : " reps"
        let target = exercise.tracking == .time && high >= 120
            ? "\(low / 60)–\(high / 60) min"
            : "\(range)\(unit)"
        let rest = exercise.restSeconds > 0 ? " · rest \(Format.rest(exercise.restSeconds))" : ""
        return "Target \(target)\(rest)"
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("SET").frame(width: 30)
            Text("PREVIOUS").frame(maxWidth: .infinity)
            switch exercise.tracking {
            case .weightReps:
                Text(WeightUnit.label(metric: metric).uppercased()).frame(width: 64)
                Text("REPS").frame(width: 52)
            case .reps:
                Text("REPS").frame(width: 64)
            case .time:
                Text("SEC").frame(width: 64)
            }
            Image(systemName: "checkmark").frame(width: 38)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Theme.textTertiary)
    }

    private func toggle(setID: UUID) {
        guard let index = exercise.sets.firstIndex(where: { $0.id == setID }) else { return }
        var set = exercise.sets[index]
        set.completed.toggle()
        if set.completed {
            switch exercise.tracking {
            case .weightReps, .reps:
                if set.reps == 0 { set.reps = exercise.targetRepsHigh }
            case .time:
                if set.seconds == 0 { set.seconds = exercise.targetRepsHigh }
            }
        }
        exercise.sets[index] = set
        if set.completed {
            Haptics.medium()
            onCompleteSet()
        } else {
            Haptics.tap()
        }
    }

    private func addSet() {
        var new = LoggedSet()
        if let last = exercise.sets.last {
            new.weightKg = last.weightKg
            new.reps = last.reps
            new.seconds = last.seconds
        } else {
            new.reps = exercise.targetRepsHigh
        }
        withAnimation { exercise.sets.append(new) }
        Haptics.tap()
    }
}

struct SetRow: View {
    let number: Int
    @Binding var set: LoggedSet
    let tracking: TrackingType
    let previous: LoggedSet?
    let metric: Bool
    let onToggle: () -> Void

    private var weightBinding: Binding<Double> {
        Binding(
            get: { (WeightUnit.display(set.weightKg, metric: metric) * 10).rounded() / 10 },
            set: { set.weightKg = WeightUnit.toKg($0, metric: metric) }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.system(.subheadline).weight(.semibold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(set.completed ? Theme.accent.opacity(0.25) : Theme.surfaceRaised))

            Button {
                copyPrevious()
            } label: {
                Text(previousLabel)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(previous == nil ? Theme.textTertiary : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(previous == nil)

            switch tracking {
            case .weightReps:
                inputBox { NumberField(placeholder: "0", value: weightBinding) }
                    .frame(width: 64)
                inputBox { IntField(placeholder: "0", value: $set.reps) }
                    .frame(width: 52)
            case .reps:
                inputBox { IntField(placeholder: "0", value: $set.reps) }
                    .frame(width: 64)
            case .time:
                inputBox { IntField(placeholder: "0", value: $set.seconds) }
                    .frame(width: 64)
            }

            Button(action: onToggle) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(set.completed ? Color.black : Theme.textTertiary)
                    .frame(width: 38, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(set.completed ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surfaceRaised))
                    )
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(set.completed ? "Set \(number) completed" : "Complete set \(number)")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(set.completed ? Theme.accent.opacity(0.08) : Color.clear)
        )
        .animation(.easeOut(duration: 0.2), value: set.completed)
    }

    private func inputBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(.subheadline).weight(.semibold))
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surfaceRaised))
    }

    private var previousLabel: String {
        guard let previous else { return "—" }
        switch tracking {
        case .weightReps:
            return "\(WeightUnit.format(previous.weightKg, metric: metric)) × \(previous.reps)"
        case .reps:
            return "× \(previous.reps)"
        case .time:
            return "\(previous.seconds)s"
        }
    }

    private func copyPrevious() {
        guard let previous else { return }
        set.weightKg = previous.weightKg
        set.reps = previous.reps
        set.seconds = previous.seconds
        Haptics.tap()
    }
}

// MARK: - Rest timer

struct RestTimerBar: View {
    let end: Date
    let total: Int
    let onAdjust: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = max(0, end.timeIntervalSince(context.date))
            let fraction = total > 0 ? remaining / Double(total) : 0
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Theme.accentGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 0) {
                    Text("REST")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(Format.duration(remaining.rounded(.up)))
                        .font(.system(size: 28, weight: .bold).monospacedDigit())
                }
                Spacer()
                timerButton("-15") { onAdjust(-15) }
                timerButton("+15") { onAdjust(15) }
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Capsule().fill(Theme.accentGradient))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.stroke))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        }
    }

    private func timerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold).monospacedDigit())
                .frame(width: 44, height: 38)
                .background(Capsule().fill(Theme.surfaceRaised))
        }
        .buttonStyle(PressableStyle())
    }
}
