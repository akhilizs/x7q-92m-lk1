import SwiftUI

/// Shows a saved plan from the store.
struct PlanDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID

    @State private var showEditor = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let plan = store.plan(id: planID) {
                PlanContentView(plan: plan, isActive: store.activePlanID == plan.id) { day in
                    if store.activeSession != nil {
                        store.isWorkoutPresented = true
                    } else {
                        store.startWorkout(day: day, plan: plan)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if store.activePlanID != plan.id {
                                Button {
                                    store.activePlanID = plan.id
                                    Haptics.success()
                                } label: { Label("Set as active plan", systemImage: "bolt.fill") }
                            }
                            Button { showEditor = true } label: { Label("Edit plan", systemImage: "pencil") }
                            Button { store.duplicatePlan(id: plan.id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                            Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                .sheet(isPresented: $showEditor) { PlanBuilderView(existing: plan).environment(store) }
                .confirmationDialog("Delete this plan?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete plan", role: .destructive) {
                        store.deletePlan(id: plan.id)
                        dismiss()
                    }
                }
            } else {
                EmptyStateView(symbol: "questionmark", title: "Plan not found", message: "It may have been deleted.")
                    .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .resumeWorkoutBar()
    }
}

/// Reusable rendering of a plan (used for saved plans and AI previews).
struct PlanContentView: View {
    let plan: WorkoutPlan
    var isActive: Bool = false
    var onStart: ((WorkoutDay) -> Void)? = nil

    @State private var selectedDay: UUID?

    private var day: WorkoutDay? {
        plan.days.first { $0.id == selectedDay } ?? plan.days.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                daySelector
                if let day {
                    dayContent(day)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .appBackground()
        .onAppear {
            if selectedDay == nil {
                let index = min(max(plan.nextDayIndex, 0), max(plan.days.count - 1, 0))
                selectedDay = plan.days.indices.contains(index) ? plan.days[index].id : nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        if isActive { VoltTag(text: "Active", symbol: "bolt.fill", filled: true) }
                        VoltTag(text: plan.goal.title)
                    }
                    Text(plan.name)
                        .font(.display(24))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(plan.source.label, systemImage: plan.source.symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    if !plan.summary.isEmpty {
                        Text(plan.summary)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                MuscleMapView(exercises: plan.days.flatMap(\.exercises))
                    .frame(width: 118, height: 158)
            }
            .graphiteCard(padding: 18, radius: 30, highlighted: isActive)

            HStack(spacing: 12) {
                miniStat("\(plan.days.count)", "days / week")
                miniStat("\(plan.totalExercises)", "exercises")
                miniStat("~\(averageMinutes)", "min / session")
            }
        }
        .padding(.top, 8)
    }

    private var averageMinutes: Int {
        guard !plan.days.isEmpty else { return 0 }
        return plan.days.reduce(0) { $0 + $1.estimatedMinutes } / plan.days.count
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.metric(20)).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 12, radius: 18)
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, d in
                    let selected = (day?.id == d.id)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedDay = d.id }
                        Haptics.tap()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Day \(index + 1)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(selected ? Theme.inkSecondary : Theme.textSecondary)
                            Text(d.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selected ? Theme.ink : Color.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(selected ? Theme.volt : Theme.surface)
                        )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func dayContent(_ day: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.focus.isEmpty ? day.name : day.focus)
                        .font(.headline)
                    Text("\(day.exercises.count) exercises · ~\(day.estimatedMinutes) min")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            ForEach(Array(day.exercises.enumerated()), id: \.element.id) { index, item in
                PlannedExerciseRow(index: index + 1, item: item)
            }
            if let onStart {
                Button {
                    onStart(day)
                    Haptics.medium()
                } label: {
                    HStack(spacing: 6) {
                        Text("Start Workout")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .buttonStyle(DarkCapsuleButtonStyle())
                .padding(.top, 6)
            }
        }
    }
}

struct PlannedExerciseRow: View {
    let index: Int
    let item: PlannedExercise

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .topLeading) {
                if let exercise = item.exercise {
                    MuscleBadge(exercise: exercise, size: 44)
                } else {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(white: 0.07))
                        .frame(width: 44, height: 44)
                }
                Text("\(index)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 19, height: 19)
                    .background(Circle().fill(Theme.volt))
                    .offset(x: -6, y: -6)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name).font(.system(size: 16, weight: .medium))
                HStack(spacing: 8) {
                    TagLabel(text: item.targetLabel, symbol: "repeat", color: .white)
                    if item.restSeconds > 0 {
                        TagLabel(text: Format.rest(item.restSeconds), symbol: "timer", color: Theme.textSecondary)
                    }
                }
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else if let cue = item.exercise?.cue {
                    Text(cue)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 14, radius: 22)
    }
}
