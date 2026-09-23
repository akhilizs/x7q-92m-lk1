import SwiftUI

/// Build a custom plan by picking exercises for each day (or edit an existing plan).
struct PlanBuilderView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let existing: WorkoutPlan?
    @State private var plan: WorkoutPlan
    @State private var pickerTarget: PickerTarget?
    @State private var makeActive = true

    private struct PickerTarget: Identifiable {
        let id: UUID
    }

    init(existing: WorkoutPlan?) {
        self.existing = existing
        let starter = WorkoutPlan(name: "My Plan", summary: "", goal: .buildMuscle, source: .custom,
                                  days: [WorkoutDay(name: "Day 1", focus: "", exercises: [])])
        _plan = State(initialValue: existing ?? starter)
    }

    private var canSave: Bool {
        !plan.name.trimmingCharacters(in: .whitespaces).isEmpty && plan.days.contains { !$0.exercises.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Plan name", text: $plan.name)
                        .font(.system(.title3).weight(.semibold))
                    Picker("Goal", selection: $plan.goal) {
                        ForEach(FitnessGoal.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    TextField("Description (optional)", text: $plan.summary, axis: .vertical)
                        .lineLimit(1...4)
                        .foregroundStyle(Theme.textSecondary)
                    if existing == nil {
                        Toggle("Make this my active plan", isOn: $makeActive)
                        .tint(Theme.sky)
                    }
                } header: {
                    Text("Plan")
                }
                .listRowBackground(Theme.surface)

                ForEach($plan.days) { $day in
                    Section {
                        ForEach($day.exercises) { $item in
                            BuilderExerciseRow(item: $item)
                        }
                        .onDelete { offsets in day.exercises.remove(atOffsets: offsets) }
                        .onMove { from, to in day.exercises.move(fromOffsets: from, toOffset: to) }

                        Button {
                            pickerTarget = PickerTarget(id: day.id)
                        } label: {
                            Label("Add exercises", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    } header: {
                        DayHeader(name: $day.name, count: day.exercises.count, canDelete: plan.days.count > 1) {
                            let id = day.id
                            withAnimation { plan.days.removeAll { $0.id == id } }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }

                Section {
                    Button {
                        withAnimation {
                            plan.days.append(WorkoutDay(name: "Day \(plan.days.count + 1)", focus: "", exercises: []))
                        }
                        Haptics.tap()
                    } label: {
                        Label("Add training day", systemImage: "calendar.badge.plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(plan.days.count >= 7)
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(existing == nil ? "Build Plan" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.headline)
                        .disabled(!canSave)
                }
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
            .sheet(item: $pickerTarget) { target in
                ExercisePickerView(title: "Add Exercises", equipment: store.profile.equipment) { exercises in
                    add(exercises, to: target.id)
                }
            }
        }
    }

    private func add(_ exercises: [Exercise], to dayID: UUID) {
        guard let index = plan.days.firstIndex(where: { $0.id == dayID }) else { return }
        let p = plan.goal.prescription
        for ex in exercises {
            let item: PlannedExercise
            if ex.tracking == .time {
                let cardio = ex.primary == .cardio
                item = PlannedExercise(exerciseID: ex.id, sets: cardio ? 1 : 3, repsLow: cardio ? 600 : 30,
                                       repsHigh: cardio ? 900 : 45, restSeconds: cardio ? 0 : 45)
            } else {
                item = PlannedExercise(exerciseID: ex.id, sets: p.sets, repsLow: p.repsLow, repsHigh: p.repsHigh,
                                       restSeconds: ex.isCompound ? p.compoundRest : p.rest)
            }
            plan.days[index].exercises.append(item)
        }
    }

    private func save() {
        var result = plan
        result.name = result.name.trimmingCharacters(in: .whitespaces)
        result.days = result.days.filter { !$0.exercises.isEmpty }
        for i in result.days.indices {
            let muscles = result.days[i].muscles.prefix(4).map(\.displayName)
            result.days[i].focus = muscles.joined(separator: " · ")
        }
        if result.summary.trimmingCharacters(in: .whitespaces).isEmpty {
            result.summary = "Custom \(result.days.count)-day plan."
        }
        result.nextDayIndex = min(result.nextDayIndex, max(result.days.count - 1, 0))
        if existing != nil {
            store.updatePlan(result)
        } else {
            store.addPlan(result, makeActive: makeActive)
        }
        Haptics.success()
        dismiss()
    }
}

private struct DayHeader: View {
    @Binding var name: String
    let count: Int
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("Day name", text: $name)
                .font(.headline)
                .foregroundStyle(.white)
                .textCase(nil)
            Text("\(count) ex")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
            }
        }
        .textCase(nil)
    }
}

private struct BuilderExerciseRow: View {
    @Binding var item: PlannedExercise

    private var isTimed: Bool { item.exercise?.tracking == .time }
    private var repStep: Int { isTimed ? (item.repsHigh >= 120 ? 60 : 5) : 1 }
    private var repRange: ClosedRange<Int> { isTimed ? 5...3600 : 1...50 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.name).font(.subheadline.weight(.semibold))
                Spacer()
                if let muscle = item.exercise?.primary {
                    TagLabel(text: muscle.displayName, color: Theme.color(for: muscle))
                }
            }
            StepperControl(label: "Sets", value: $item.sets, range: 1...10)
            StepperControl(label: isTimed ? "Min time" : "Min reps", value: minBinding, range: repRange, step: repStep,
                           format: { isTimed ? Format.rest($0) : "\($0)" })
            StepperControl(label: isTimed ? "Max time" : "Max reps", value: maxBinding, range: repRange, step: repStep,
                           format: { isTimed ? Format.rest($0) : "\($0)" })
            StepperControl(label: "Rest", value: $item.restSeconds, range: 0...600, step: 15,
                           format: { Format.rest($0) })
        }
        .padding(.vertical, 6)
    }

    private var minBinding: Binding<Int> {
        Binding(get: { item.repsLow }, set: { newValue in
            item.repsLow = newValue
            if item.repsHigh < newValue { item.repsHigh = newValue }
        })
    }

    private var maxBinding: Binding<Int> {
        Binding(get: { item.repsHigh }, set: { newValue in
            item.repsHigh = newValue
            if item.repsLow > newValue { item.repsLow = newValue }
        })
    }
}

/// Searchable multi-select exercise picker, filtered by muscle and available equipment.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let equipment: Set<Equipment>
    let onAdd: ([Exercise]) -> Void

    @State private var search = ""
    @State private var muscle: MuscleGroup?
    @State private var onlyMyEquipment = true
    @State private var selected: [String] = []

    private var filtered: [Exercise] {
        ExerciseLibrary.all.filter { ex in
            (muscle == nil || ex.primary == muscle)
                && (!onlyMyEquipment || ex.isAvailable(with: equipment))
                && (search.isEmpty || ex.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MuscleFilterBar(selection: $muscle)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    Toggle("Only equipment I have", isOn: $onlyMyEquipment)
                        .tint(Theme.sky)
                }
                .listRowBackground(Theme.surface)

                Section {
                    ForEach(filtered) { ex in
                        Button {
                            toggle(ex.id)
                        } label: {
                            PickerRow(exercise: ex, order: selected.firstIndex(of: ex.id).map { $0 + 1 })
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(filtered.count) exercises")
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selected.isEmpty ? "Add" : "Add (\(selected.count))") {
                        onAdd(selected.compactMap { ExerciseLibrary.exercise($0) })
                        Haptics.success()
                        dismiss()
                    }
                    .font(.headline)
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else {
            selected.append(id)
        }
        Haptics.tap()
    }
}

private struct PickerRow: View {
    let exercise: Exercise
    let order: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.primary.symbol)
                .font(.subheadline)
                .foregroundStyle(Theme.color(for: exercise.primary))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.color(for: exercise.primary).opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.subheadline.weight(.semibold))
                Text("\(exercise.primary.displayName) · \(exercise.equipmentLabel)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .strokeBorder(order == nil ? Theme.textTertiary : Color.clear, lineWidth: 1.5)
                    .background(Circle().fill(order == nil ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Theme.accentGradient)))
                if let order {
                    Text("\(order)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                }
            }
            .frame(width: 26, height: 26)
        }
        .contentShape(Rectangle())
    }
}
