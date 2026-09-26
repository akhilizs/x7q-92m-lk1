import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(AppStore.self) private var store

    @State private var restEnd: Date?
    @State private var restTotal = 0
    @State private var showPicker = false
    @State private var showFinish = false
    @State private var banner: String?
    @State private var swapTarget: LoggedExercise?
    @State private var guideExercise: Exercise?
    @State private var plateRequest: PlateRequest?

    struct PlateRequest: Identifiable {
        let id = UUID()
        let exercise: Exercise?
        let weightKg: Double
    }

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
                                suggestion: store.suggestion(for: exercise.exerciseID, low: exercise.targetRepsLow,
                                                             high: exercise.targetRepsHigh),
                                supersetLabel: supersetLabel(for: exercise),
                                canSupersetWithNext: canSupersetWithNext(exercise.id),
                                metric: store.profile.useMetric,
                                actions: actions(for: exercise)
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
            .overlay(alignment: .top) {
                if let banner {
                    Label(banner, systemImage: "arrow.turn.down.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.lilac))
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                        .padding(.top, 96)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityIdentifier("workoutBanner")
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: restEnd)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: banner)
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
                RestLiveActivity.stop()
            }
            .task(id: banner) {
                guard banner != nil else { return }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if !Task.isCancelled { banner = nil }
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
            .sheet(item: $swapTarget) { target in
                SwapExerciseSheet(current: target,
                                  equipment: store.profile.equipment,
                                  excluding: Set(store.activeSession?.exercises.map(\.exerciseID) ?? [])) { replacement in
                    swap(target.id, with: replacement)
                }
            }
            .sheet(item: $guideExercise) { exercise in
                NavigationStack { ExerciseGuideView(exercise: exercise) }
            }
            .sheet(item: $plateRequest) { request in
                NavigationStack {
                    PlateCalculatorView(exercise: request.exercise, startKg: request.weightKg,
                                        metric: store.profile.useMetric)
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                RestNotifier.requestAuthorization()
                RestLiveActivity.endFinished()
            }
        }
    }

    // MARK: Top bar

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

    // MARK: Card actions

    private func actions(for exercise: LoggedExercise) -> ExerciseLogCard.Actions {
        ExerciseLogCard.Actions(
            completedSet: { setID in handleCompletedSet(exerciseID: exercise.id, setID: setID) },
            remove: { remove(exerciseID: exercise.id) },
            swap: { swapTarget = exercise },
            guide: { guideExercise = exercise.exercise },
            plates: { kg in plateRequest = PlateRequest(exercise: exercise.exercise, weightKg: kg) },
            supersetWithNext: { linkWithNext(exercise.id) },
            leaveSuperset: { unlink(exercise.id) }
        )
    }

    private func remove(exerciseID: UUID) {
        withAnimation {
            store.activeSession?.exercises.removeAll { $0.id == exerciseID }
            cleanUpSupersets()
        }
    }

    /// Swaps an exercise; sets already done stay logged under the original.
    private func swap(_ exerciseID: UUID, with replacement: Exercise) {
        guard var session = store.activeSession,
              let index = session.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let old = session.exercises[index]
        var fresh = store.makeLoggedExercise(for: replacement)
        if fresh.tracking == old.tracking {
            fresh.targetRepsLow = old.targetRepsLow
            fresh.targetRepsHigh = old.targetRepsHigh
            fresh.restSeconds = old.restSeconds
        }
        fresh.supersetGroup = old.supersetGroup
        let remaining = max(old.workingSets.filter { !$0.completed }.count, 1)
        if let template = fresh.sets.first {
            fresh.sets = (0..<remaining).map { i in
                var set = i < fresh.sets.count ? fresh.sets[i] : template
                set.id = UUID()
                return set
            }
        }
        let done = old.sets.filter(\.completed)
        withAnimation {
            if done.isEmpty {
                session.exercises[index] = fresh
            } else {
                var kept = old
                kept.sets = done
                session.exercises[index] = kept
                session.exercises.insert(fresh, at: index + 1)
            }
            store.activeSession = session
        }
        banner = "Swapped in \(replacement.name)"
        Haptics.success()
    }

    // MARK: Supersets

    private func supersetLabel(for exercise: LoggedExercise) -> String? {
        guard let group = exercise.supersetGroup, let session = store.activeSession else { return nil }
        var groups: [UUID] = []
        for ex in session.exercises {
            if let g = ex.supersetGroup, !groups.contains(g) { groups.append(g) }
        }
        guard let index = groups.firstIndex(of: group) else { return nil }
        let letters = Array("ABCDEFGHIJ")
        return "Superset \(letters[index % letters.count])"
    }

    private func canSupersetWithNext(_ exerciseID: UUID) -> Bool {
        guard let exercises = store.activeSession?.exercises,
              let index = exercises.firstIndex(where: { $0.id == exerciseID }),
              index + 1 < exercises.count else { return false }
        let current = exercises[index].supersetGroup
        return current == nil || exercises[index + 1].supersetGroup != current
    }

    private func linkWithNext(_ exerciseID: UUID) {
        guard var session = store.activeSession,
              let index = session.exercises.firstIndex(where: { $0.id == exerciseID }),
              index + 1 < session.exercises.count else { return }
        let group = session.exercises[index].supersetGroup ?? session.exercises[index + 1].supersetGroup ?? UUID()
        let absorbed = session.exercises[index + 1].supersetGroup
        for i in session.exercises.indices where session.exercises[i].supersetGroup == absorbed && absorbed != nil {
            session.exercises[i].supersetGroup = group
        }
        session.exercises[index].supersetGroup = group
        session.exercises[index + 1].supersetGroup = group
        withAnimation { store.activeSession = session }
        Haptics.tap()
    }

    private func unlink(_ exerciseID: UUID) {
        guard var session = store.activeSession,
              let index = session.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        session.exercises[index].supersetGroup = nil
        withAnimation {
            store.activeSession = session
            cleanUpSupersets()
        }
    }

    /// A superset needs at least two exercises.
    private func cleanUpSupersets() {
        guard var session = store.activeSession else { return }
        var counts: [UUID: Int] = [:]
        for ex in session.exercises { if let g = ex.supersetGroup { counts[g, default: 0] += 1 } }
        for i in session.exercises.indices {
            if let g = session.exercises[i].supersetGroup, counts[g] ?? 0 < 2 { session.exercises[i].supersetGroup = nil }
        }
        store.activeSession = session
    }

    // MARK: Rest

    /// Decides what happens after a set: straight into a drop set or the next superset
    /// exercise, a short rest after warm-ups, otherwise the exercise's rest.
    private func handleCompletedSet(exerciseID: UUID, setID: UUID) {
        guard let session = store.activeSession,
              let index = session.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let exercise = session.exercises[index]
        guard let setIndex = exercise.sets.firstIndex(where: { $0.id == setID }) else { return }
        let set = exercise.sets[setIndex]

        if setIndex + 1 < exercise.sets.count, exercise.sets[setIndex + 1].kind == .drop, !exercise.sets[setIndex + 1].completed {
            banner = "Drop set — strip the weight and go"
            return
        }
        if let group = exercise.supersetGroup, !set.isWarmup {
            let members = session.exercises.filter { $0.supersetGroup == group }
            if let position = members.firstIndex(where: { $0.id == exerciseID }) {
                let later = members[(position + 1)...].first { $0.sets.contains { !$0.completed && !$0.isWarmup } }
                if let next = later {
                    banner = "Superset → \(next.name)"
                    return
                }
            }
            let rest = members.map(\.restSeconds).max() ?? exercise.restSeconds
            startRest(seconds: rest, after: exercise.id)
            return
        }
        startRest(seconds: set.isWarmup ? min(60, exercise.restSeconds) : exercise.restSeconds, after: exercise.id)
    }

    private func startRest(seconds: Int, after exerciseID: UUID) {
        guard seconds > 0 else { return }
        restTotal = seconds
        let end = Date().addingTimeInterval(TimeInterval(seconds))
        restEnd = end
        let next = nextUpName(after: exerciseID)
        RestNotifier.schedule(after: seconds, next: next)
        RestLiveActivity.start(end: end, nextUp: next, workoutName: store.activeSession?.name ?? "Workout")
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
        RestLiveActivity.update(end: newEnd, nextUp: "")
        Haptics.tap()
    }

    private func skipRest() {
        restEnd = nil
        RestNotifier.cancel()
        RestLiveActivity.stop()
    }

    private func nextUpName(after exerciseID: UUID) -> String {
        guard let session = store.activeSession else { return "" }
        if let current = session.exercises.first(where: { $0.id == exerciseID }),
           current.sets.contains(where: { !$0.completed }) {
            return current.name
        }
        return session.exercises.first { ex in ex.sets.contains { !$0.completed } }?.name ?? ""
    }
}

// MARK: - Exercise card

struct ExerciseLogCard: View {
    struct Actions {
        var completedSet: (UUID) -> Void
        var remove: () -> Void
        var swap: () -> Void
        var guide: () -> Void
        var plates: (Double) -> Void
        var supersetWithNext: () -> Void
        var leaveSuperset: () -> Void
    }

    @Binding var exercise: LoggedExercise
    let previous: [LoggedSet]
    let suggestion: OverloadSuggestion?
    let supersetLabel: String?
    let canSupersetWithNext: Bool
    let metric: Bool
    let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let suggestion, exercise.workingSets.contains(where: { !$0.completed }) {
                SuggestionChip(suggestion: suggestion, tracking: exercise.tracking, metric: metric) {
                    apply(suggestion)
                }
            }
            if !exercise.notes.isEmpty {
                Label(exercise.notes, systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accentAlt)
            }
            columnHeader
            VStack(spacing: 8) {
                ForEach($exercise.sets) { $set in
                    let info = setInfo(set.id)
                    SetRow(label: info.label,
                           accessibilityNumber: info.number,
                           set: $set,
                           tracking: exercise.tracking,
                           previous: info.previous,
                           metric: metric,
                           onToggle: { toggle(setID: set.id) })
                }
            }
            HStack(spacing: 10) {
                smallButton("Add set", symbol: "plus") { addSet() }
                if exercise.sets.count > 1 {
                    smallButton("Remove set", symbol: "minus") {
                        withAnimation { _ = exercise.sets.popLast() }
                        Haptics.tap()
                    }
                }
            }
        }
        .cardStyle(padding: 14, radius: 22)
        .overlay(alignment: .leading) {
            if supersetLabel != nil {
                Capsule()
                    .fill(Theme.lilac)
                    .frame(width: 4)
                    .padding(.vertical, 18)
                    .offset(x: -2)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            let muscle = exercise.exercise?.primary ?? .fullBody
            Button(action: actions.guide) {
                IconBadge(symbol: muscle.symbol, background: Theme.color(for: muscle), foreground: Theme.ink, size: 42)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("How to do \(exercise.name)")
            VStack(alignment: .leading, spacing: 4) {
                if let supersetLabel {
                    Text(supersetLabel.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.lilac)
                }
                Text(exercise.name)
                    .font(.system(.headline).weight(.semibold))
                Text(targetText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            menu
        }
    }

    private var menu: some View {
        Menu {
            Button(action: actions.guide) { Label("How to do it", systemImage: "questionmark.circle") }
            Button(action: actions.swap) { Label("Swap exercise", systemImage: "arrow.left.arrow.right") }
            if exercise.tracking == .weightReps {
                Section {
                    if !exercise.sets.contains(where: \.isWarmup) {
                        Button { addWarmups() } label: { Label("Add warm-up sets", systemImage: "flame") }
                    }
                    Button { addDropSet() } label: { Label("Add drop set", systemImage: "arrow.down.right") }
                    if Warmup.usesBar(exercise.exercise) {
                        Button { actions.plates(workingWeight) } label: { Label("Plate calculator", systemImage: "circle.grid.2x1") }
                    }
                }
            }
            Section {
                if canSupersetWithNext {
                    Button(action: actions.supersetWithNext) { Label("Superset with next", systemImage: "link") }
                }
                if exercise.supersetGroup != nil {
                    Button(action: actions.leaveSuperset) { Label("Remove from superset", systemImage: "link.badge.plus") }
                }
            }
            Button(role: .destructive, action: actions.remove) {
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

    private func smallButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.surfaceRaised))
        }
        .buttonStyle(PressableStyle())
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

    /// Warm-ups are labelled W and don't shift the working set numbers or the "previous" column.
    private func setInfo(_ setID: UUID) -> (label: String, number: Int, previous: LoggedSet?) {
        var working = 0
        for set in exercise.sets {
            if !set.isWarmup { working += 1 }
            if set.id == setID {
                if set.isWarmup { return ("W", 0, nil) }
                let previousSet = working - 1 < previous.count ? previous[working - 1] : nil
                return (set.kind.badge ?? "\(working)", working, previousSet)
            }
        }
        return ("", 0, nil)
    }

    private var workingWeight: Double {
        exercise.workingSets.first(where: { !$0.completed })?.weightKg
            ?? exercise.workingSets.first?.weightKg ?? 0
    }

    private func apply(_ suggestion: OverloadSuggestion) {
        for i in exercise.sets.indices where !exercise.sets[i].completed && exercise.sets[i].kind != .warmup && exercise.sets[i].kind != .drop {
            if let kg = suggestion.weightKg { exercise.sets[i].weightKg = kg }
            if let reps = suggestion.reps { exercise.sets[i].reps = reps }
            if let seconds = suggestion.seconds { exercise.sets[i].seconds = seconds }
        }
        Haptics.success()
    }

    private func addWarmups() {
        let ramp = Warmup.sets(for: exercise.exercise, workingKg: workingWeight, metric: metric)
        guard !ramp.isEmpty else { return }
        withAnimation { exercise.sets.insert(contentsOf: ramp, at: 0) }
        Haptics.tap()
    }

    private func addDropSet() {
        let last = exercise.workingSets.last
        let lighter = Progression.roundToLoadable((last?.weightKg ?? 0) * 0.8, exercise: exercise.exercise,
                                                  metric: metric, down: true)
        let drop = LoggedSet(weightKg: (last?.weightKg ?? 0) > 0 ? lighter : 0,
                             reps: last?.reps ?? exercise.targetRepsHigh, kind: .drop)
        withAnimation { exercise.sets.append(drop) }
        Haptics.tap()
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
            actions.completedSet(set.id)
        } else {
            Haptics.tap()
        }
    }

    private func addSet() {
        var new = LoggedSet()
        if let last = exercise.workingSets.last {
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

/// "Today: 62.5 kg × 8" with the reason, tap to fill the remaining sets.
struct SuggestionChip: View {
    let suggestion: OverloadSuggestion
    let tracking: TrackingType
    let metric: Bool
    let onApply: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint))
            VStack(alignment: .leading, spacing: 2) {
                Text("Today: \(target)")
                    .font(.subheadline.weight(.semibold))
                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button("Use", action: onApply)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(Color.white))
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Use suggestion")
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceRaised))
    }

    private var target: String {
        switch tracking {
        case .weightReps:
            let unit = WeightUnit.label(metric: metric)
            let weight = suggestion.weightKg.map { "\(WeightUnit.format($0, metric: metric)) \(unit)" } ?? ""
            return suggestion.reps.map { "\(weight) × \($0)" } ?? weight
        case .reps:
            return suggestion.reps.map { "\($0) reps" } ?? ""
        case .time:
            return suggestion.seconds.map { "\($0) s" } ?? ""
        }
    }

    private var symbol: String {
        switch suggestion.kind {
        case .addWeight: return "arrow.up"
        case .addReps, .holdLonger: return "plus"
        case .repeatWeight: return "equal"
        case .deload: return "arrow.down"
        }
    }

    private var tint: Color {
        switch suggestion.kind {
        case .addWeight: return Theme.sage
        case .addReps, .holdLonger: return Theme.sky
        case .repeatWeight: return Theme.sand
        case .deload: return Theme.rose
        }
    }
}

struct SetRow: View {
    let label: String
    let accessibilityNumber: Int
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
            setMenu

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
            .accessibilityLabel(checkLabel)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(set.completed ? Theme.accent.opacity(0.08) : Color.clear)
        )
        .opacity(set.isWarmup && !set.completed ? 0.8 : 1)
        .animation(.easeOut(duration: 0.2), value: set.completed)
    }

    /// Tap the set number to change its type or log RPE.
    private var setMenu: some View {
        Menu {
            Picker("Set type", selection: $set.kind) {
                ForEach(SetKind.allCases, id: \.self) { kind in
                    Label(kind.title, systemImage: kind.symbol).tag(kind)
                }
            }
            Menu("RPE (effort)") {
                Button("None") { set.rpe = nil }
                ForEach(Array(stride(from: 6.0, through: 10.0, by: 0.5)), id: \.self) { value in
                    Button(rpeText(value) + " · " + rpeMeaning(value)) { set.rpe = value }
                }
            }
        } label: {
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundStyle(labelColor)
                if let rpe = set.rpe {
                    Text("@\(rpeText(rpe))")
                        .font(.system(size: 8, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 30, height: 30)
            .background(Circle().fill(set.completed ? Theme.accent.opacity(0.25) : Theme.surfaceRaised))
        }
        .accessibilityLabel("Set \(label) options")
    }

    private var labelColor: Color {
        switch set.kind {
        case .normal: return .white
        case .warmup: return Theme.sand
        case .drop: return Theme.sky
        case .failure: return Theme.rose
        }
    }

    private var checkLabel: String {
        if set.isWarmup { return set.completed ? "Warm-up set completed" : "Complete warm-up set" }
        return set.completed ? "Set \(accessibilityNumber) completed" : "Complete set \(accessibilityNumber)"
    }

    private func rpeText(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func rpeMeaning(_ value: Double) -> String {
        switch value {
        case 10: return "max effort"
        case 9...: return "1 rep left"
        case 8...: return "2 reps left"
        case 7...: return "3 reps left"
        default: return "easy"
        }
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
