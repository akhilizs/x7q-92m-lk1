import SwiftUI

struct PlansView: View {
    @Environment(AppStore.self) private var store
    @State private var showGenerator = false
    @State private var showBuilder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    createSection
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Programs")
                        if store.plans.isEmpty {
                            Text("No plans yet — generate one or build your own.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        ForEach(orderedPlans) { plan in
                            NavigationLink(value: plan.id) {
                                PlanCard(plan: plan, isActive: plan.id == store.activePlanID)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    ExerciseLibraryLink()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Plans")
            .navigationDestination(for: UUID.self) { id in
                PlanDetailView(planID: id)
            }
            .resumeWorkoutBar()
            .sheet(isPresented: $showGenerator) { GeneratePlanView().environment(store) }
            .sheet(isPresented: $showBuilder) { PlanBuilderView(existing: nil).environment(store) }
        }
    }

    /// Active plan first, then the rest newest first.
    private var orderedPlans: [WorkoutPlan] {
        let active = store.plans.filter { $0.id == store.activePlanID }
        return active + store.plans.filter { $0.id != store.activePlanID }
    }

    private var createSection: some View {
        HStack(spacing: 12) {
            Button {
                showGenerator = true
            } label: {
                ZStack(alignment: .bottomLeading) {
                    PhotoBackdrop(name: "WorkoutPress", alignment: .top, gradientStart: 0.1)
                    VStack(alignment: .leading, spacing: 6) {
                        if store.hasAPIKey {
                            AIBadge()
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        Spacer()
                        Text("Generate a plan")
                            .font(.system(size: 18, weight: .semibold))
                        Text("From your goal and the machines you have")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(PressableStyle())

            Button {
                showBuilder = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    VoltTag(text: "Custom")
                    Spacer()
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.volt))
                        .padding(.bottom, 6)
                    Text("Build your own")
                        .font(.display(16))
                        .foregroundStyle(.white)
                    Text("Pick every exercise, set and rep")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .graphiteCard(padding: 14)
                .frame(height: 200)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.top, 4)
    }
}

/// A program: name, goal and the muscles it trains, lit up on a front and back body.
struct PlanCard: View {
    let plan: WorkoutPlan
    let isActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    if isActive {
                        VoltTag(text: "Active", symbol: "bolt.fill", filled: true)
                    }
                    VoltTag(text: plan.goal.title)
                }
                Text(plan.name)
                    .font(.display(19))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    MetaLabel(symbol: "calendar", text: "\(plan.days.count) days")
                    MetaLabel(symbol: "list.bullet", text: "\(plan.totalExercises) ex")
                    MetaLabel(symbol: plan.source.symbol, text: plan.source.shortLabel)
                }
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            MuscleMapView(exercises: plan.days.flatMap(\.exercises))
                .frame(width: 104, height: 136)
        }
        .frame(minHeight: 136)
        .graphiteCard(padding: 16, highlighted: isActive)
    }
}

private struct ExerciseLibraryLink: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationLink {
            ExerciseLibraryView()
        } label: {
            HStack(spacing: 14) {
                IconBadge(symbol: "books.vertical.fill", size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Exercise library").font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                    Text("\(store.exerciseCatalog.count) exercises · add your own")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .cardStyle(padding: 14, radius: 22)
        }
        .buttonStyle(PressableStyle())
    }
}

struct ExerciseLibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    @State private var muscle: MuscleGroup?
    @State private var creating = false
    @State private var editing: CustomExercise?

    private var filtered: [Exercise] {
        store.exerciseCatalog.filter { ex in
            (muscle == nil || ex.primary == muscle) &&
            (search.isEmpty || ex.name.localizedCaseInsensitiveContains(search))
        }
    }

    private var trimmedSearch: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MuscleFilterBar(selection: $muscle)
                Button {
                    creating = true
                } label: {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "plus", background: Theme.volt, foreground: Theme.ink, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(trimmedSearch.isEmpty ? "Create your own exercise" : "Create “\(trimmedSearch)”")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Use it in plans and workouts, and your AI coach can pick it too.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .cardStyle(padding: 12, radius: 20)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(trimmedSearch.isEmpty ? "Create your own exercise" : "Create \(trimmedSearch) as your own exercise")
                .accessibilityIdentifier("libraryCreateExercise")

                LazyVStack(spacing: 10) {
                    ForEach(filtered) { ex in
                        ExerciseInfoRow(exercise: ex, onEdit: ex.isCustom ? { editing = store.customExercise(id: ex.id) } : nil)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .appBackground()
        .navigationTitle("Exercises")
        .searchable(text: $search, prompt: "Search exercises")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New exercise")
            }
        }
        .sheet(isPresented: $creating) {
            CustomExerciseForm(suggestedName: trimmedSearch) { _ in
                search = ""
                muscle = nil
            }
        }
        .sheet(item: $editing) { exercise in
            CustomExerciseForm(exercise: exercise)
        }
        .resumeWorkoutBar()
    }
}

struct ExerciseInfoRow: View {
    let exercise: Exercise
    /// Set for the user's own exercises.
    var onEdit: (() -> Void)? = nil
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MuscleBadge(exercise: exercise, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(exercise.name).font(.subheadline.weight(.medium))
                        if exercise.isCustom { CustomExerciseTag() }
                    }
                    Text("\(exercise.primary.displayName) · \(exercise.equipmentLabel)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            if expanded {
                Text(exercise.cue)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                if !exercise.secondary.isEmpty {
                    Text("Also works: " + exercise.secondary.map(\.displayName).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                HStack(spacing: 18) {
                    NavigationLink {
                        ExerciseGuideView(exercise: exercise, showsDone: false)
                    } label: {
                        Label("How to do it", systemImage: "questionmark.circle")
                            .font(.footnote.weight(.semibold))
                    }
                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(.footnote.weight(.semibold))
                        }
                        .accessibilityLabel("Edit \(exercise.name)")
                    }
                }
            }
        }
        .cardStyle(padding: 12, radius: 20)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expanded.toggle() }
        }
    }
}

struct MuscleFilterBar: View {
    @Binding var selection: MuscleGroup?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { selection = nil } label: {
                    Chip(title: "All", isSelected: selection == nil)
                }
                .buttonStyle(.plain)
                ForEach(MuscleGroup.allCases) { muscle in
                    Button {
                        selection = selection == muscle ? nil : muscle
                        Haptics.tap()
                    } label: {
                        Chip(title: muscle.displayName, isSelected: selection == muscle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
