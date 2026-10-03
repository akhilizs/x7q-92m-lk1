import SwiftUI

/// Create or edit one of the user's own exercises.
struct CustomExerciseForm: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var exercise: CustomExercise
    @State private var confirmDelete = false
    private let isNew: Bool
    private let onSaved: ((CustomExercise) -> Void)?

    init(exercise: CustomExercise? = nil, suggestedName: String = "", onSaved: ((CustomExercise) -> Void)? = nil) {
        _exercise = State(initialValue: exercise ?? CustomExercise(name: suggestedName.trimmingCharacters(in: .whitespacesAndNewlines)))
        isNew = exercise == nil
        self.onSaved = onSaved
    }

    private var canSave: Bool { !exercise.trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TextField("Exercise name", text: $exercise.name)
                        .font(.system(size: 22, weight: .semibold))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier("exerciseName")
                        .cardStyle(padding: 16, radius: 20)

                    field("Main muscle") {
                        FlowLayout(spacing: 8) {
                            ForEach(MuscleGroup.allCases) { muscle in
                                chip(muscle.displayName, id: "primary.\(muscle.rawValue)", isSelected: exercise.primary == muscle) {
                                    exercise.primary = muscle
                                    exercise.secondary.removeAll { $0 == muscle }
                                }
                            }
                        }
                    }

                    field("Also works", note: "Optional") {
                        FlowLayout(spacing: 8) {
                            ForEach(MuscleGroup.allCases.filter { $0 != exercise.primary }) { muscle in
                                chip(muscle.displayName, id: "secondary.\(muscle.rawValue)", isSelected: exercise.secondary.contains(muscle)) {
                                    if let index = exercise.secondary.firstIndex(of: muscle) {
                                        exercise.secondary.remove(at: index)
                                    } else {
                                        exercise.secondary.append(muscle)
                                    }
                                }
                            }
                        }
                    }

                    field("How you log it") {
                        Picker("Logging", selection: $exercise.tracking) {
                            Text("Weight × reps").tag(TrackingType.weightReps)
                            Text("Reps").tag(TrackingType.reps)
                            Text("Time").tag(TrackingType.time)
                        }
                        .pickerStyle(.segmented)
                        Text(trackingHint)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    field("Equipment", note: "Leave empty for bodyweight") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(EquipmentCategory.allCases) { category in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(category.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textTertiary)
                                    FlowLayout(spacing: 8) {
                                        ForEach(Equipment.inCategory(category).filter { $0 != .bodyweight }) { item in
                                            chip(item.displayName, id: "equipment.\(item.rawValue)", isSelected: exercise.equipment.contains(item)) {
                                                if let index = exercise.equipment.firstIndex(of: item) {
                                                    exercise.equipment.remove(at: index)
                                                } else {
                                                    exercise.equipment.append(item)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Toggle(isOn: $exercise.isCompound) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Compound movement")
                            Text("Works several joints, like a squat or a row. Gets a longer rest.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.volt)
                    .cardStyle(padding: 14, radius: 20)

                    field("Form notes", note: "Optional") {
                        TextField("Cues to remember, seat height, grip…", text: $exercise.notes, axis: .vertical)
                            .lineLimit(3...6)
                            .cardStyle(padding: 14, radius: 20)
                    }

                    Button {
                        save()
                    } label: {
                        Label(isNew ? "Save exercise" : "Save changes", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)

                    if !isNew {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Delete exercise").foregroundStyle(Theme.danger)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .navigationTitle(isNew ? "New Exercise" : "Edit Exercise")
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
            }
            .confirmationDialog("Delete \(exercise.trimmedName)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete exercise", role: .destructive) {
                    store.deleteCustomExercise(id: exercise.id)
                    Haptics.warning()
                    dismiss()
                }
            } message: {
                Text("It's removed from the exercise list. Plans and past workouts that use it keep it.")
            }
        }
    }

    private var trackingHint: String {
        switch exercise.tracking {
        case .weightReps: return "Log the weight and reps of each set, like a dumbbell press."
        case .reps: return "Log reps only, like push-ups."
        case .time: return "Log time, like a plank hold or a bike ride."
        }
    }

    private func save() {
        guard canSave else { return }
        store.saveCustomExercise(exercise)
        Haptics.success()
        onSaved?(store.customExercise(id: exercise.id) ?? exercise)
        dismiss()
    }

    private func field<Content: View>(_ title: String, note: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            content()
        }
    }

    private func chip(_ title: String, id: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Chip(title: title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Small tag marking an exercise the user created.
struct CustomExerciseTag: View {
    var body: some View {
        Text("Custom")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.lilac))
    }
}
